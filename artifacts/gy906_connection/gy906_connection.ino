#include <M5Unified.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

/* =========================================================================
   --- GY-906 (MLX90614) MODIFIED VERSION ---
   =========================================================================
   
   1. BLE CHARACTERISTIC
      UUID: 04933a4f-756a-4801-9823-7b199fe93b5e
      Type: Notify

   2. PAYLOAD STRUCTURE (14 Bytes Total)
      The payload is a raw byte array representing 7 x Int16 values.
      
      [ Byte 0-1 ] : Accelerometer X (Int16)
      [ Byte 2-3 ] : Accelerometer Y (Int16)
      [ Byte 4-5 ] : Accelerometer Z (Int16)
      [ Byte 6-7 ] : Gyroscope X     (Int16)
      [ Byte 8-9 ] : Gyroscope Y     (Int16)
      [ Byte 10-11]: Gyroscope Z     (Int16)
      [ Byte 12-13]: Object Temp     (UInt16 cast to Int16) <--- NEW END

   3. DIFFERENTIATION STRATEGY
      - Old Device (MAX30100): Payload size = 16 bytes.
      - New Device (GY-906)  : Payload size = 14 bytes.

   4. DATA SCALING
      - IMU: Same as previous.
      - TEMP: Raw value sent. 
              To get Celsius in App: (RawValue * 0.02) - 273.15
   =========================================================================
*/

// --- CONFIG ---
#define SDA_PIN 32
#define SCL_PIN 33
// MLX90614 Standard Address
#define MLX90614_ADDR 0x5A 
// MLX90614 RAM Register for Object 1 Temperature
#define MLX90614_TOBJ1 0x07

// --- BLE CONFIG ---
#define SERVICE_UUID        "95d7f9ea-24f1-48e1-840e-704143664f57"
#define CHARACTERISTIC_UUID "04933a4f-756a-4801-9823-7b199fe93b5e"

// --- GLOBALS ---
BLECharacteristic *pCharacteristic;
bool deviceConnected = false;
bool sensorFound = false;
uint16_t global_rawTemp = 0; // Stores raw MLX90614 data

// ==========================================
//   CUSTOM SOFTWARE I2C (BIT-BANGING)
//   (Kept identical to preserve pin timing)
// ==========================================
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
        _sda = sda;
        _scl = scl;
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
            if (data & 0x80) sda_high();
            else sda_low();
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
        if (sendAck) sda_low();
        else sda_high();
        i2c_delay();
        scl_high(); i2c_delay();
        scl_low(); i2c_delay();
        sda_high(); 
        return data;
    }
};

SoftI2C swWire;

// --- SENSOR HELPER FUNCTIONS ---
// Modified for MLX90614 Read Sequence (SMBus style)
// Start -> Addr+W -> Reg -> Start -> Addr+R -> LowByte -> HighByte -> PEC(ignore) -> Stop
void readTempSensor() {
    swWire.start();
    swWire.writeByte(MLX90614_ADDR << 1); // Write Addr
    swWire.writeByte(MLX90614_TOBJ1);     // Command: Read Object 1 Temp
    
    // Repeated Start for Reading
    swWire.start();
    swWire.writeByte((MLX90614_ADDR << 1) | 1); // Read Addr
    
    // Read 3 bytes: Low, High, PEC (Packet Error Code)
    uint8_t t_low  = swWire.readByte(true);  // ACK
    uint8_t t_high = swWire.readByte(true);  // ACK
    uint8_t pec    = swWire.readByte(false); // NACK (End of transmission)
    
    swWire.stop();

    // Combine bytes (Little Endian)
    global_rawTemp = (t_high << 8) | t_low;
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
    // 1. M5 Init
    auto cfg = M5.config();
    M5.begin(cfg);
    
    // 2. SoftI2C Init
    swWire.begin(SDA_PIN, SCL_PIN);

    // 3. Sensor Check (Ping the GY-906)
    swWire.start();
    bool ack = swWire.writeByte(MLX90614_ADDR << 1);
    swWire.stop();

    if (ack) {
        sensorFound = true;
        M5.Lcd.fillScreen(BLACK);
        M5.Lcd.setTextColor(CYAN); // Cyan to distinguish visually from old version
        M5.Lcd.setTextSize(2);
        M5.Lcd.setCursor(10, 10);
        M5.Lcd.println("GY-906 OK");
        // MLX90614 generally does not require config registers for basic operation
    } else {
        M5.Lcd.fillScreen(RED);
        M5.Lcd.setTextColor(WHITE);
        M5.Lcd.setTextSize(2);
        M5.Lcd.setCursor(10, 10);
        M5.Lcd.println("NO SENSOR");
    }

    // 4. BLE Setup
    BLEDevice::init("Magical Watch GY906"); // Optional Name Change
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
    delay(10); 

    // 1. Read Internal IMU
    float ax, ay, az, gx, gy, gz;
    M5.Imu.getAccel(&ax, &ay, &az);
    M5.Imu.getGyro(&gx, &gy, &gz);

    // 2. Read GY-906 (Software I2C)
    if (sensorFound) {
        readTempSensor();
    }

    // 3. Pack Payload for Flutter
    if (deviceConnected) {
        int16_t payload[7]; 

        payload[0] = (int16_t)(ax * 1000);
        payload[1] = (int16_t)(ay * 1000);
        payload[2] = (int16_t)(az * 1000);
        
        payload[3] = (int16_t)(gx * 10);
        payload[4] = (int16_t)(gy * 10);
        payload[5] = (int16_t)(gz * 10);
        
        if (sensorFound) {
            // Send Raw Value
            payload[6] = (int16_t)global_rawTemp;
        } else {
            // Error Flag (impossible temp)
            payload[6] = 0; 
        }

        // ESP32 is Little Endian, sends [LSB, MSB]
        pCharacteristic->setValue((uint8_t *)payload, sizeof(payload));
        pCharacteristic->notify();
    }
}