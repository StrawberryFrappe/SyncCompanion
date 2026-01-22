# Bio Signal Processing Revision: Fresh Implementation Review

## Context
The `BioSignalProcessor` class in `lib/services/device/bio_signal_processor.dart` processes raw IR and Red LED values from a MAX30100 pulse oximeter sensor to calculate BPM and SpO2. The implementation has gone through multiple iterations to fix issues, but continues to have problems with:

1. **False Positives:** Reporting "Human Detected" when pointing at fabric/air/random objects.
2. **False Negatives:** Not detecting humans when finger is clearly on sensor.
3. **Stability:** Readings fluctuate or never stabilize.

## Current Architecture

### Data Flow
```
Raw IR/Red (uint16, 0-65535) from Bluetooth
    ↓
device_service.dart: TelemetryData.fromBytes() 
    ↓
bio_signal_processor.dart: process(rawIr, rawRed)
    ↓
BioData { bpm, spo2, fingerDetected, humanDetected }
```

### Signal Processing Pipeline (Current)
1. **DC Removal:** High-pass filter to remove baseline drift (`DCRemover` class, alpha=0.95)
2. **Low-Pass Filter:** Butterworth LPF (Fs=100Hz, Fc=6Hz) to reject high-frequency noise
3. **Beat Detection:** State machine (`_BeatState`) looking for peaks/valleys in filtered signal
4. **SpO2 Calculation:** Log-ratio method with TI lookup table

### Key Thresholds (Current Values)
```dart
_minRawIrForFinger = 5000        // Raw IR > this = finger present
_minPeakToPeakAmplitude = 2.0    // Filtered amplitude for "strong signal"
_minBpmForHuman = 40             // BPM range for valid human
_maxBpmForHuman = 180
_minSpo2ForHuman = 85            // Minimum SpO2% to consider valid
_consecutiveValidSamples > 50   // 0.5s sustained finger presence
_bpmHistory.length >= 3          // Need 3+ BPM samples
_spo2History.isNotEmpty          // Need SpO2 readings
bpmStdDev < 25.0                 // BPM variance limit
```

## Known Issues

### Issue 1: Beat Detection May Not Be Triggering
The beat detector uses a state machine that looks for:
- Signal crossing above threshold → follow slope
- Signal dropping below threshold → maybe detected
- Significant drop (`sample + _stepResiliency < _threshold`) → beat confirmed

**Potential Problems:**
- Threshold constants may not match the actual signal amplitude after filtering
- The `_initHoldoffMs = 2000` means no beats for first 2 seconds
- `_stepResiliency = 30.0` may be too large/small for the filtered signal range

### Issue 2: SpO2 Never Updates
SpO2 only updates after `_beatsPerSpO2Calculation = 4` beats are detected. If beat detection isn't working, SpO2 stays at 0, which fails `_spo2History.isNotEmpty`.

### Issue 3: Circular Dependencies
Multiple checks depend on each other:
- `humanDetected` requires valid BPM history
- BPM history requires beat detection
- Beat detection requires stable signal
- Stable signal check may be too strict

## Your Task

### 1. Analyze the Current Implementation
- Study the `process()` method flow
- Understand each filter and its purpose
- Map out the state machine transitions
- Identify where thresholds might be wrong

### 2. Add Debug Logging (Temporarily)
Add print statements to trace:
```dart
print('IR: $rawIr, Filtered: $filteredIr, State: $_state, Threshold: $_threshold');
print('Beat: $beatDetected, BPM: $bpm, SpO2: $_currentSpO2');
print('History: ${_bpmHistory.length}, Consecutive: $_consecutiveValidSamples');
```
This will help understand what's happening in real-time.

### 3. Validate Beat Detection
- Check if `filteredIr` values are in a reasonable range (what is the actual amplitude?)
- Verify the state machine is transitioning correctly
- Consider if threshold values need adjustment based on actual signal ranges

### 4. Simplify Human Detection (Initially)
Start with minimal requirements and add checks incrementally:
```dart
// Start simple:
final humanDetected = fingerDetected && displayBpm > 0 && displaySpO2 > 0;

// Then add checks one by one and test each:
// + _bpmHistory.length >= 3
// + _consecutiveValidSamples > 50
// + isBpmStable
```

### 5. Consider Alternative Approaches
- **Peak Detection:** Instead of state machine, try simple peak detection with minimum distance
- **Autocorrelation:** For BPM, find periodicity via autocorrelation of filtered signal
- **Adaptive Thresholds:** Scale thresholds based on observed signal amplitude

## Reference Materials

### MAX30100 Arduino Library
The current implementation is based on:
- https://github.com/oxullo/Arduino-MAX30100
- Key files: `MAX30100_BeatDetector.cpp`, `MAX30100_SpO2Calculator.cpp`

### SpO2 Calculation Reference
- TI Application Note: http://www.ti.com/lit/an/slaa274b/slaa274b.pdf
- Uses R-value (ratio of ratios) mapped to SpO2 via lookup table

## Files to Modify
- [bio_signal_processor.dart](file:///h:/SyncCompanion/lib/services/device/bio_signal_processor.dart) - Main processing logic

## Success Criteria
1. **No finger:** `humanDetected = false`, `fingerDetected = false`, BPM = 0, SpO2 = 0
2. **Finger on sensor (stable):** `humanDetected = true` within 3-5 seconds, BPM in 50-100 range (resting), SpO2 in 95-100%
3. **Pointing at fabric/air:** `humanDetected = false` (even if IR fluctuates)
4. **Moving finger:** May temporarily lose detection, should recover within 2-3 seconds

## Notes
- Sample rate is 100Hz (10ms between samples)
- Raw IR/Red values are unsigned 16-bit (0-65535)
- Sensor error is indicated by 65535 (0xFFFF)
- Very low IR (<1000) indicates no object near sensor
