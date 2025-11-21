#include <M5Unified.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID "95d7f9ea-24f1-48e1-840e-704143664f57"
#define CHARACTERISTIC_UUID "04933a4f-756a-4801-9823-7b199fe93b5e"

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

bool isScreenOn = true;

class ServerCallback : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    deviceConnected = true;

    if (isScreenOn) {
      M5.Lcd.fillScreen(BLACK);
      M5.Lcd.setCursor(0, 0);
      M5.Lcd.println("BLE IMU Sender");
      M5.Lcd.println("Client Connected!");
    }
  }

  void onDisconnect(BLEServer *pServer) {
    deviceConnected = false;

    if (isScreenOn) {
      M5.Lcd.fillScreen(BLACK);
      M5.Lcd.setCursor(0, 0);
      M5.Lcd.println("BLE IMU Sender");
      M5.Lcd.println("Client Disconnected");
      M5.Lcd.println("Advertising...");
    }
    BLEDevice::getAdvertising()->start();
  }
};

void setup() {
  auto cfg = M5.config();
  M5.begin(cfg);

  if (!M5.Imu.isEnabled()) {
    M5.Lcd.println("IMU initialization failed!");
    while (1) delay(100);
  }

  M5.Lcd.setRotation(1);
  M5.Lcd.setTextSize(2);

  BLEDevice::init("M5-IMU-Sensor");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallback());
  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY);

  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMaxPreferred(0x12);
  BLEDevice::startAdvertising();

  M5.Lcd.println("Advertising...");
}

void loop() {
  M5.update();

  if (M5.BtnA.wasPressed()) {  // BtnA is the main front button
    isScreenOn = !isScreenOn;  // Toggle the state

    if (!isScreenOn) {
      M5.Lcd.fillScreen(BLACK);  // Clear screen when turning off
      M5.Lcd.setCursor(10, 10);
      M5.Lcd.print("Screen Off...");
    } else {
      // Screen is on, redraw header and status
      M5.Lcd.fillScreen(BLACK);
      M5.Lcd.setCursor(0, 0);
      M5.Lcd.println("BLE IMU Sender");
      if (deviceConnected) {
        M5.Lcd.println("Client Connected!");
      } else {
        M5.Lcd.println("Advertising...");
      }
    }
  }


  // --- This logic runs whether screen is on or off ---
  float ax_f, ay_f, az_f, gx_f, gy_f, gz_f;
  M5.Imu.getAccel(&ax_f, &ay_f, &az_f);
  M5.Imu.getGyro(&gx_f, &gy_f, &gz_f);


  if (isScreenOn) {
    M5.Lcd.fillRect(0, 50, M5.Lcd.width(), 100, BLACK);

    // Print Accel data
    M5.Lcd.setCursor(0, 50);
    M5.Lcd.printf("A:");
    M5.Lcd.setCursor(40, 50);
    M5.Lcd.printf("% 6.2f", ax_f);  // % 6.2f = pad with spaces to 6 chars wide
    M5.Lcd.setCursor(40, 75);
    M5.Lcd.printf("% 6.2f", ay_f);
    M5.Lcd.setCursor(40, 100);
    M5.Lcd.printf("% 6.2f", az_f);

    // Print Gyro data
    M5.Lcd.setCursor(M5.Lcd.width() / 2, 50);  // Start halfway across the screen
    M5.Lcd.printf("G:");
    M5.Lcd.setCursor(M5.Lcd.width() / 2 + 40, 50);
    M5.Lcd.printf("% 6.1f", gx_f);  // % 6.1f = pad to 6 chars, 1 decimal place
    M5.Lcd.setCursor(M5.Lcd.width() / 2 + 40, 75);
    M5.Lcd.printf("% 6.1f", gy_f);
    M5.Lcd.setCursor(M5.Lcd.width() / 2 + 40, 100);
    M5.Lcd.printf("% 6.1f", gz_f);
  }


  // --- This BLE logic also runs whether screen is on or off ---
  if (deviceConnected) {

    // **HOW WE CONVERT:**
    // We multiply our float by a power of 10 to preserve decimal precision,
    // and then "cast" it to an int16_t, which chops off any remaining fraction.

    // Create our 12-byte payload buffer (6 integers * 2 bytes each)
    int16_t payload[6];

    // **ACCELEROMETER (Accel):**
    // Values are in G's (e.g., 1.23). We want to keep 2 decimal places.
    // - Multiply by 100: 1.23 * 100 = 123.0
    // - Cast to int16_t: (int16_t)123.0 = 123
    // - This fits: Max Accel (e.g., 16G) * 100 = 1600 (well within 32,767)
    payload[0] = (int16_t)(ax_f * 100);
    payload[1] = (int16_t)(ay_f * 100);
    payload[2] = (int16_t)(az_f * 100);

    // **GYROSCOPE (Gyro):**
    // Values are in degrees/second (e.g., 250.5, or up to 2000.0).
    // We *cannot* use 100 here. 2000.0 * 100 = 200,000, which overflows 32,767.
    // So, we must accept only 1 decimal place of precision.
    // - Multiply by 10: 250.5 * 10 = 2505.0
    // - Cast to int16_t: (int16_t)2505.0 = 2505
    // - This fits: Max Gyro (e.g., 2000.0) * 10 = 20000 (well within 32,767)
    payload[3] = (int16_t)(gx_f * 10);
    payload[4] = (int16_t)(gy_f * 10);
    payload[5] = (int16_t)(gz_f * 10);

    // **HOW TO REVERSE THIS (DECODING):**
    // The client (e.g., a phone app, a Python script) will receive this
    // 12-byte array (e.g., [b1, b2, b3, b4, ..., b12]).
    //
    // 1. **Reassemble:** The client must read the 12 bytes and rebuild the six
    //    16-bit signed integers. For example, it would combine bytes 1 & 2
    //    into the first integer, bytes 3 & 4 into the second, and so on.
    //    (This is hardware-dependent, but for ESP32 it's "little-endian".)
    //
    // 2. **Convert:** Once it has the 6 integers (let's call them p[0]..p[5]),
    //    it reverses our math by *dividing* by the same amount we multiplied by.
    //
    //    float received_ax = (float)p[0] / 100.0;
    //    float received_ay = (float)p[1] / 100.0;
    //    float received_az = (float)p[2] / 100.0;
    //
    //    float received_gx = (float)p[3] / 10.0;
    //    float received_gy = (float)p[4] / 10.0;
    //    float received_gz = (float)p[5] / 10.0;
    //
    // --- End of Explanation ---

    pCharacteristic->setValue((uint8_t *)payload, sizeof(payload));  // 12 bytes
    pCharacteristic->notify();
  }

  
  delay(50);
}