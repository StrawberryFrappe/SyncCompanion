#include <M5Unified.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

/* =========================================================================
   --- IMPORTANT INFO ---
   =========================================================================
   
   1. BLE CHARACTERISTIC
      UUID: 04933a4f-756a-4801-9823-7b199fe93b5e
      Type: Notify
      Frequency: ~60Hz

   2. PAYLOAD STRUCTURE (16 Bytes Total)
      The payload is a raw byte array representing 8 x Int16 values.
      Endianness: Little Endian (Standard ESP32 memory order: LSB first).
      
      [ Byte 0-1 ] : Accelerometer X (Int16)
      [ Byte 2-3 ] : Accelerometer Y (Int16)
      [ Byte 4-5 ] : Accelerometer Z (Int16)
      [ Byte 6-7 ] : Gyroscope X     (Int16)
      [ Byte 8-9 ] : Gyroscope Y     (Int16)
      [ Byte 10-11]: Gyroscope Z     (Int16)
      [ Byte 12-13]: Bio Sensor IR   (UInt16 cast to Int16)
      [ Byte 14-15]: Bio Sensor RED  (UInt16 cast to Int16)

   3. DATA INTERPRETATION & SCALING
      
      A. IMU (Bytes 0-11)
         - Raw Value: Signed 16-bit Integer.
         - Conversion Logic:
           double accel_x_G = (int16_value) / 1000.0;  // Result in Gs
           double gyro_x_DPS = (int16_value) / 10.0;   // Result in Degrees Per Second

      B. BIO SENSOR (Bytes 12-15)
         - Raw Value: Unsigned 16-bit Integer (0 to 65535).
         - Note: In Dart/Flutter, read as Uint16 or read as Int16 and cast:
           int irValue = (payload[13] << 8) | payload[12]; // Manual Little Endian Reconstruction
         
         - Value Meanings:
           - -1 (0xFFFF): Sensor Error / Disconnected.
           - 0          : Sensor Initialize / Empty.
           - > 0        : Raw Light Intensity.
         
         - Algorithm Implementation:
           1. DC Removal: The raw signal has a huge DC offset. Apply a DC Blocker 
              or High-Pass Filter (cutoff ~0.5Hz) to center the signal around 0.
           2. Heart Beat: Detect peaks or zero-crossings on the filtered 'IR' channel.
           3. SpO2: Calculate AC/DC ratio for both Red and IR. 
              R = (AC_Red/DC_Red) / (AC_Ir/DC_Ir).
              SpO2 = 110 - 25 * R.
   =========================================================================
*/

// --- CONFIG ---
#define SDA_PIN 32
#define SCL_PIN 33
#define MAX30100_ADDR 0x57

// --- BLE CONFIG ---
#define SERVICE_UUID        "95d7f9ea-24f1-48e1-840e-704143664f57"
#define CHARACTERISTIC_UUID "04933a4f-756a-4801-9823-7b199fe93b5e"

// --- GLOBALS ---
BLECharacteristic *pCharacteristic;
bool deviceConnected = false;
bool sensorFound = false;
uint16_t global_rawIR = 0;
uint16_t global_rawRed = 0;

// ==========================================
//   CUSTOM SOFTWARE I2C (BIT-BANGING)
// ==========================================
// This class manually toggles pins to bypass M5Unified resource conflicts.
class SoftI2C {
  private:
    int _sda, _scl;

    // Tuning delay for stable communication
    void i2c_delay() { 
        for(volatile int i=0; i<50; i++); 
    }

    void sda_high() { pinMode(_sda, INPUT_PULLUP); } // Float High
    void sda_low()  { pinMode(_sda, OUTPUT); digitalWrite(_sda, LOW); } // Drive Low
    void scl_high() { pinMode(_scl, INPUT_PULLUP); }
    void scl_low()  { pinMode(_scl, OUTPUT); digitalWrite(_scl, LOW); }
    
    int read_sda()  { return digitalRead(_sda); }

  public:
    void begin(int sda, int scl) {
        _sda = sda; _scl = scl;
        pinMode(_sda, INPUT_PULLUP);
        pinMode(_scl, INPUT_PULLUP);
        scl_high(); sda_high();
    }

    void start() {
        sda_high(); scl_high(); i2c_delay();
        sda_low();  i2c_delay();
        scl_low();  i2c_delay();
    }

    void stop() {
        sda_low(); i2c_delay();
        scl_high(); i2c_delay();
        sda_high(); i2c_delay();
    }

    bool writeByte(uint8_t data) {
        for (uint8_t i = 0; i < 8; i++) {
            if (data & 0x80) sda_high(); else sda_low();
            data <<= 1;
            i2c_delay();
            scl_high(); i2c_delay();
            scl_low();  i2c_delay();
        }
        // Read ACK
        sda_high(); i2c_delay();
        scl_high(); i2c_delay();
        bool ack = !read_sda();
        scl_low(); i2c_delay();
        return ack;
    }

    uint8_t readByte(bool sendAck) {
        uint8_t data = 0;
        sda_high();
        for (uint8_t i = 0; i < 8; i++) {
            data <<= 1;
            scl_high(); i2c_delay();
            if (read_sda()) data |= 1;
            scl_low(); i2c_delay();
        }
        if (sendAck) sda_low(); else sda_high();
        i2c_delay();
        scl_high(); i2c_delay();
        scl_low(); i2c_delay();
        sda_high(); 
        return data;
    }
};

SoftI2C swWire;

// --- SENSOR HELPER FUNCTIONS ---
void writeRegister(uint8_t reg, uint8_t val) {
    swWire.start();
    swWire.writeByte(MAX30100_ADDR << 1); // Write Addr
    swWire.writeByte(reg);
    swWire.writeByte(val);
    swWire.stop();
}

void readFIFO() {
    swWire.start();
    swWire.writeByte(MAX30100_ADDR << 1); // Write Addr
    swWire.writeByte(0x05);               // FIFO Data Reg
    
    // Repeated Start for Reading
    swWire.start();
    swWire.writeByte((MAX30100_ADDR << 1) | 1); // Read Addr
    
    // Read 4 bytes: IR_High, IR_Low, Red_High, Red_Low
    uint8_t ir_h = swWire.readByte(true);  // ACK
    uint8_t ir_l = swWire.readByte(true);  // ACK
    uint8_t r_h  = swWire.readByte(true);  // ACK
    uint8_t r_l  = swWire.readByte(false); // NACK (Stop)
    swWire.stop();

    // Combine bytes into global variables
    global_rawIR  = (ir_h << 8) | ir_l;
    global_rawRed = (r_h << 8) | r_l;
}

// --- BLE CALLBACKS ---
class ServerCallback : public BLEServerCallbacks {
    void onConnect(BLEServer *pServer) { deviceConnected = true; }
    void onDisconnect(BLEServer *pServer) { 
        deviceConnected = false; 
        BLEDevice::getAdvertising()->start(); 
    }
};

void setup() {
    // 1. M5 Init (Handles Internal Hardware I2C for IMU/Power)
    auto cfg = M5.config();
    M5.begin(cfg);
    
    // 2. SoftI2C Init (Manual Pins for Bio Sensor)
    swWire.begin(SDA_PIN, SCL_PIN);

    // 3. Sensor Initialization Sequence
    swWire.start();
    bool ack = swWire.writeByte(MAX30100_ADDR << 1);
    swWire.stop();

    if (ack) {
        sensorFound = true;
        M5.Lcd.fillScreen(BLACK);
        M5.Lcd.setTextColor(GREEN);
        M5.Lcd.setTextSize(2);
        M5.Lcd.setCursor(10, 10);
        M5.Lcd.println("SENSOR OK");
        
        // Configure MAX30100 Registers
        writeRegister(0x06, 0x40); // Reset
        delay(10);
        writeRegister(0x06, 0x03); // Mode = SpO2 + HR
        writeRegister(0x07, 0x07); // Config = 100Hz Sample Rate, 1600us Pulse Width
        writeRegister(0x09, 0xFF); // LED Current = MAX (50mA) - Needed for thick housing
        writeRegister(0x02, 0x00); // Clear FIFO Write Ptr
        writeRegister(0x03, 0x00); // Clear FIFO Overflow
        writeRegister(0x04, 0x00); // Clear FIFO Read Ptr
    } else {
        M5.Lcd.fillScreen(RED);
        M5.Lcd.setTextColor(WHITE);
        M5.Lcd.setTextSize(2);
        M5.Lcd.setCursor(10, 10);
        M5.Lcd.println("NO SENSOR");
    }

    // 4. BLE Setup
    BLEDevice::init("Magical Watch of Measurement");
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallback());
    BLEService *pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_NOTIFY);
    pCharacteristic->addDescriptor(new BLE2902());
    pService->start();
    BLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);
    BLEDevice::startAdvertising();
}

void loop() {
    M5.update();
    
    // 60Hz Loop Cycle (~16ms)
    delay(16); 

    // 1. Read Internal IMU (Hardware I2C)
    float ax, ay, az, gx, gy, gz;
    M5.Imu.getAccel(&ax, &ay, &az);
    M5.Imu.getGyro(&gx, &gy, &gz);

    // 2. Read Bio Sensor (Software I2C)
    if (sensorFound) {
        readFIFO();
    }

    // 3. Pack Payload for Flutter
    if (deviceConnected) {
        int16_t payload[8];
        
        // Scaling Logic (Matches Documentation)
        payload[0] = (int16_t)(ax * 1000); // g -> mg
        payload[1] = (int16_t)(ay * 1000);
        payload[2] = (int16_t)(az * 1000);
        
        payload[3] = (int16_t)(gx * 10);   // dps -> dps*10
        payload[4] = (int16_t)(gy * 10);
        payload[5] = (int16_t)(gz * 10);
        
        if (sensorFound) {
            payload[6] = (int16_t)global_rawIR;
            payload[7] = (int16_t)global_rawRed;
        } else {
            payload[6] = -1; // Error Flag
            payload[7] = -1;
        }

        // ESP32 is Little Endian, sends [LSB, MSB] for each int16
        pCharacteristic->setValue((uint8_t *)payload, sizeof(payload));
        pCharacteristic->notify();
    }
}