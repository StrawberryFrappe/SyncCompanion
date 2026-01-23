#include <M5Unified.h>
#include <Wire.h>
#include "MAX30100_PulseOximeter.h"

// --- PIN CONFIGURATION ---
// If the sensor is not found, or you get flatline 0s, 
// SWAP THESE TO: SDA 33, SCL 32 (Professors sometimes solder backwards!)
#define I2C_SDA 2
#define I2C_SCL 1

#define REPORTING_PERIOD_MS 1000

PulseOximeter pox;
uint32_t tsLastReport = 0;

// Callback: This fires the INSTANT the sensor sees a heartbeat spike.
// If you don't see this printing, the sensor is not reading your blood flow.
void onBeatDetected() {
    Serial.println("BEAT! (Pulse detected)");
    M5.Lcd.fillCircle(10, 10, 5, RED); // Visual flash
    delay(10); // Tiny visual hold (usually bad, but fine for this simple test)
    M5.Lcd.fillCircle(10, 10, 5, BLACK);
}

void setup() {
    // 1. Initialize M5 (Required to turn on the 5V Power Rail for the Groove Port)
    auto cfg = M5.config();
    M5.begin(cfg);
    
    // Basic Screen Setup
    M5.Lcd.setRotation(1);
    M5.Lcd.setTextSize(2);
    M5.Lcd.fillScreen(BLACK);
    M5.Lcd.println("MAX30100 TEST");

    Serial.begin(115200);
    Serial.print("Initializing Pulse Oximeter..");

    // 2. FORCE the I2C Pins. 
    // We do this AFTER M5.begin to override any default settings.
    Wire.begin(I2C_SDA, I2C_SCL);

    // 3. Initialize Sensor
    if (!pox.begin()) {
        Serial.println("FAILED");
        M5.Lcd.setTextColor(RED);
        M5.Lcd.println("FAILED!");
        M5.Lcd.println("Check Wiring.");
        for(;;); // Stop here
    } else {
        Serial.println("SUCCESS");
        M5.Lcd.setTextColor(GREEN);
        M5.Lcd.println("SUCCESS!");
        M5.Lcd.setTextColor(WHITE);
        M5.Lcd.println("Place finger...");
    }

    // 4. MAX POWER MODE
    // We boost the LED current to 50mA to see through skin better.
    pox.setIRLedCurrent(MAX30100_LED_CURR_50MA);

    // Register the callback
    pox.setOnBeatDetectedCallback(onBeatDetected);
}

void loop() {
    // 1. Critical Update Loop
    // This must run fast. No heavy delays here.
    pox.update();

    // 2. Reporting Loop (Every 1 second)
    if (millis() - tsLastReport > REPORTING_PERIOD_MS) {
        
        // Print to Serial
        Serial.print("Heart rate: ");
        Serial.print(pox.getHeartRate());
        Serial.print(" bpm / SpO2: ");
        Serial.print(pox.getSpO2());
        Serial.println(" %");

        // Print to Screen (Minimal to save speed)
        M5.Lcd.fillRect(0, 40, M5.Lcd.width(), 60, BLACK); // Clear old text
        M5.Lcd.setCursor(0, 40);
        M5.Lcd.print("BPM: ");
        M5.Lcd.println(pox.getHeartRate());
        M5.Lcd.print("SpO2: ");
        M5.Lcd.print(pox.getSpO2());
        M5.Lcd.println("%");

        tsLastReport = millis();
    }
}