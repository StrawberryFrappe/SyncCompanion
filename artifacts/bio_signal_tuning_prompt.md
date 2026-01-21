# Bio Signal Processing Tuning Task

## Objective
Tune the pulse oximeter signal processing in SyncCompanion to eliminate false positives when no finger is on the sensor (e.g., pointing at air).

## Current State
- Device: M5 with MAX30100 pulse oximeter sensor
- Firmware: `h:\SyncCompanion\artifacts\IMU_BLE_Connection\IMU_BLE_Connection.ino`
- Signal processor: `h:\SyncCompanion\lib\services\device\bio_signal_processor.dart`
- BPM/SpO2 display works but produces false readings when no finger present

## Problem
When sensor is pointed at air (no finger), it still shows BPM/SpO2 values instead of 0/0.

## Reference Implementation
Study the Arduino-MAX30100 library for proper signal quality detection:
- https://github.com/gabriel-milan/Arduino-MAX30100
- Key files: `MAX30100_BeatDetector.cpp`, `MAX30100_SpO2Calculator.cpp`, `MAX30100_PulseOximeter.cpp`

## Suggested Approaches

1. **Signal Quality Detection**
   - Check if DC component (`_dcIr`) is above a threshold indicating finger presence
   - Reference library note: "With no finger on sensor, both values should be close to zero"

2. **Amplitude-Based Filtering**
   - If the filtered signal amplitude is too small, reject as noise
   - Use the `_minThreshold = 20` constant more effectively

3. **Beat Validity Check**
   - Require stable beat intervals before showing BPM
   - Reject if beat-to-beat variability is too high (noise produces erratic intervals)

4. **SpO2 Sanity Check**
   - Only show SpO2 if ratio `R` is in physiologically valid range (0.4-1.0)
   - Reject if calculated SpO2 would be < 80% or > 100%

## Files to Examine
- `h:\SyncCompanion\lib\services\device\bio_signal_processor.dart` - Main algorithm
- `h:\SyncCompanion\lib\screens\pulse_oximeter\pulse_oximeter_screen.dart` - UI display
- `h:\SyncCompanion\artifacts\IMU_BLE_Connection\IMU_BLE_Connection.ino` - Device firmware

## Success Criteria
- Pointing at air → shows 0 BPM, 0 SpO2
- Finger on sensor → shows realistic BPM (60-100 at rest), SpO2 (95-100%)
- Stable readings without rapid fluctuations
