import 'dart:async';
import 'dart:collection';
import 'dart:math';

/// Processed bio-sensor data with calculated vitals.
class BioData {
  /// Raw infrared value from sensor (null if sensor error or not present)
  final int? rawIr;
  
  /// Raw red LED value from sensor (null if sensor error or not present)
  final int? rawRed;
  
  /// Filtered IR signal (DC removed) for waveform display
  final double filteredIr;
  
  /// Calculated heart rate in BPM (0 if not enough data)
  final int bpm;
  
  /// Calculated SpO2 percentage (0 if not enough data)
  final int spo2;
  
  /// Whether the sensor is connected and working
  final bool sensorConnected;
  
  /// Whether finger/wrist is detected on sensor (based on signal magnitude)
  final bool fingerDetected;
  
  /// Whether a human is detected (valid BPM and SpO2)
  final bool humanDetected;
  
  const BioData({
    this.rawIr,
    this.rawRed,
    this.filteredIr = 0.0,
    this.bpm = 0,
    this.spo2 = 0,
    this.sensorConnected = false,
    this.fingerDetected = false,
    this.humanDetected = false,
  });
  
  @override
  String toString() => 'BioData(bpm: $bpm, spo2: $spo2%, ir: $rawIr, red: $rawRed, finger: $fingerDetected)';
}

/// Beat detector states (based on MAX30100 reference implementation)
enum _BeatState {
  init,
  waiting,
  followingSlope,
  maybeDetected,
  masking,
}

/// Processes raw bio-sensor data from MAX30100 pulse oximeter.
/// 
/// Based on the reference implementation from Arduino-MAX30100 library.
/// Uses state machine for beat detection and log-ratio for SpO2.
class BioSignalProcessor {
  // Timing configuration (converted to sample counts at 60Hz)
  static const double _sampleRate = 60.0;
  static const double _samplePeriodMs = 1000.0 / _sampleRate; // ~16.67ms
  
  // Beat detector constants (from reference library)
  static const double _initHoldoffMs = 2000; // Wait before counting
  static const double _maskingHoldoffMs = 200; // Non-retriggerable window after beat
  static const double _invalidReadoutDelayMs = 2000; // Reset if no beat for this long
  static const double _bpFilterAlpha = 0.6; // EMA factor for beat period
  static const double _minThreshold = 20.0; // Minimum filtered value to consider
  static const double _maxThreshold = 800.0; // Maximum threshold
  static const double _stepResiliency = 30.0; // Max negative jump to trigger beat edge
  static const double _thresholdFalloffTarget = 0.3;
  static const double _thresholdDecayFactor = 0.99;
  
  // SpO2 constants
  static const int _beatsPerSpO2Calculation = 4;
  
  // SpO2 lookup table (from TI reference: http://www.ti.com/lit/an/slaa274b/slaa274b.pdf)
  static const List<int> _spO2LUT = [
    100,100,100,100,99,99,99,99,99,99,98,98,98,98,
    98,97,97,97,97,97,97,96,96,96,96,96,96,95,95,
    95,95,95,95,94,94,94,94,94,93,93,93,93,93
  ];
  
  // Human detection parameters
  static const int _minBpmForHuman = 40;
  static const int _maxBpmForHuman = 180;
  static const int _minSpo2ForHuman = 85;
  
  // Finger/wrist presence detection
  // When no finger, DC values are low (close to 0). With finger/wrist, DC magnitude is high.
  // Values can go negative on wrist - check absolute magnitude.
  static const double _minDcMagnitudeForFinger = 500.0;
  
  // Signal amplitude validation - minimum peak-to-peak amplitude to consider valid
  static const double _minPeakToPeakAmplitude = 30.0;
  
  // Beat stability - max variation between consecutive beat intervals
  static const double _maxBeatVariabilityRatio = 0.5; // 50%
  
  // SpO2 physiological range (wrist readings stay >90%)
  static const int _minPhysiologicalSpO2 = 70;
  static const int _maxPhysiologicalSpO2 = 100;
  
  // DC removal state
  double _dcIr = 0.0;
  double _dcRed = 0.0;
  bool _dcInitialized = false;
  static const double _dcAlpha = 0.95;
  
  // Beat detector state
  _BeatState _state = _BeatState.init;
  double _threshold = _minThreshold;
  double _beatPeriod = 0;
  double _lastMaxValue = 0;
  int _tsLastBeat = 0; // In sample counts
  int _sampleCount = 0;
  double _lastBeatIntervalMs = 0; // For beat stability check
  int _initStartSample = 0;
  
  // Waveform buffer
  final Queue<double> _irBuffer = Queue<double>();
  static const int _bufferSeconds = 5;
  
  // Amplitude tracking for finger detection
  double _recentMinIr = 0;
  double _recentMaxIr = 0;
  int _amplitudeSampleCount = 0;
  static const int _amplitudeWindowSamples = 60; // 1 second at 60Hz
  
  // SpO2 calculator state
  double _irAcSqSum = 0;
  double _redAcSqSum = 0;
  int _spO2SamplesRecorded = 0;
  int _beatsDetectedNum = 0;
  int _currentSpO2 = 0;
  
  // Human detection - rolling history
  final Queue<int> _bpmHistory = Queue<int>();
  final Queue<int> _spo2History = Queue<int>();
  int _lastValidBpm = 0;
  int _lastValidSpO2 = 0;
  
  // Stream controller
  final StreamController<BioData> _bioDataController = StreamController.broadcast();
  Stream<BioData> get bioData$ => _bioDataController.stream;
  
  // Latest values for synchronous access
  BioData _latestBioData = const BioData();
  BioData get latestBioData => _latestBioData;
  
  /// Process raw IR and RED values from the sensor.
  void process(int rawIr, int rawRed) {
    // Handle sensor error/disconnected state
    if (rawIr == -1 || rawIr == 65535 || rawRed == -1 || rawRed == 65535) {
      _latestBioData = const BioData(
        sensorConnected: false,
        humanDetected: false,
      );
      _bioDataController.add(_latestBioData);
      return;
    }
    
    // Handle sensor initializing (both zero)
    if (rawIr == 0 && rawRed == 0) {
      _latestBioData = const BioData(
        rawIr: 0,
        rawRed: 0,
        sensorConnected: true,
        fingerDetected: false,
        humanDetected: false,
      );
      _bioDataController.add(_latestBioData);
      return;
    }
    
    _sampleCount++;
    
    // === DC Removal (Exponential Moving Average) ===
    if (!_dcInitialized) {
      _dcIr = rawIr.toDouble();
      _dcRed = rawRed.toDouble();
      _dcInitialized = true;
      _initStartSample = _sampleCount;
    } else {
      _dcIr = _dcAlpha * _dcIr + (1 - _dcAlpha) * rawIr;
      _dcRed = _dcAlpha * _dcRed + (1 - _dcAlpha) * rawRed;
    }
    
    final filteredIr = rawIr - _dcIr;
    final filteredRed = rawRed - _dcRed;
    
    // === Finger/Wrist Presence Detection ===
    // Check DC magnitude - with no finger, values are low (close to 0)
    // With finger/wrist, DC magnitude is high (can go negative on wrist)
    final dcMagnitude = _dcIr.abs();
    final fingerDetected = _dcInitialized && dcMagnitude >= _minDcMagnitudeForFinger;
    
    // Track amplitude for additional validation
    _updateAmplitudeTracking(filteredIr);
    final amplitude = _recentMaxIr - _recentMinIr;
    final signalStrong = amplitude >= _minPeakToPeakAmplitude;
    
    // If no finger detected, reset state and return zeros
    if (!fingerDetected) {
      _resetOnNoFinger();
      _latestBioData = BioData(
        rawIr: rawIr,
        rawRed: rawRed,
        filteredIr: filteredIr,
        bpm: 0,
        spo2: 0,
        sensorConnected: true,
        fingerDetected: false,
        humanDetected: false,
      );
      _bioDataController.add(_latestBioData);
      return;
    }
    
    // === Store for waveform display ===
    final maxBufferSize = (_sampleRate * _bufferSeconds).toInt();
    _irBuffer.addLast(filteredIr);
    while (_irBuffer.length > maxBufferSize) {
      _irBuffer.removeFirst();
    }
    
    // === Beat Detection (State Machine) ===
    // The state machine will naturally reset if no valid beats found
    final beatDetected = _checkForBeat(filteredIr);
    
    // === SpO2 Calculation ===
    _updateSpO2(filteredIr, filteredRed, beatDetected);
    
    // === Calculate BPM from beat period ===
    int bpm = 0;
    if (_beatPeriod > 0 && signalStrong) {
      // beatPeriod is in ms
      bpm = (60000.0 / _beatPeriod).round().clamp(30, 220);
    }
    
    // Update history for valid values (only if signal is strong)
    if (signalStrong && bpm >= _minBpmForHuman && bpm <= _maxBpmForHuman) {
      _lastValidBpm = bpm;
      _bpmHistory.addLast(bpm);
      while (_bpmHistory.length > 30) _bpmHistory.removeFirst();
    }
    
    // SpO2 sanity check - must be in physiological range
    int validSpO2 = _currentSpO2;
    if (validSpO2 < _minPhysiologicalSpO2 || validSpO2 > _maxPhysiologicalSpO2) {
      validSpO2 = 0; // Invalid reading
    }
    
    if (signalStrong && validSpO2 >= _minSpo2ForHuman) {
      _lastValidSpO2 = validSpO2;
      _spo2History.addLast(validSpO2);
      while (_spo2History.length > 10) _spo2History.removeFirst();
    }
    
    // Display last valid values (persistence) - only if signal still strong
    final displayBpm = (signalStrong && bpm > 0) ? bpm : (signalStrong ? _lastValidBpm : 0);
    final displaySpO2 = (signalStrong && validSpO2 > 0) ? validSpO2 : (signalStrong ? _lastValidSpO2 : 0);
    
    // Human detection - need consistent history and valid readings
    final humanDetected = signalStrong &&
                          _bpmHistory.length >= 3 && 
                          _spo2History.isNotEmpty &&
                          displayBpm >= _minBpmForHuman && 
                          displayBpm <= _maxBpmForHuman;
    
    _latestBioData = BioData(
      rawIr: rawIr,
      rawRed: rawRed,
      filteredIr: filteredIr,
      bpm: displayBpm,
      spo2: displaySpO2,
      sensorConnected: true,
      fingerDetected: fingerDetected,
      humanDetected: humanDetected,
    );
    
    _bioDataController.add(_latestBioData);
  }
  
  /// State machine beat detection (based on MAX30100 reference).
  bool _checkForBeat(double sample) {
    bool beatDetected = false;
    final timeSinceLastBeatMs = (_sampleCount - _tsLastBeat) * _samplePeriodMs;
    final timeSinceInitMs = (_sampleCount - _initStartSample) * _samplePeriodMs;
    
    switch (_state) {
      case _BeatState.init:
        // Wait for init holdoff before starting detection
        if (timeSinceInitMs > _initHoldoffMs) {
          _state = _BeatState.waiting;
        }
        break;
        
      case _BeatState.waiting:
        if (sample > _threshold) {
          _threshold = min(sample, _maxThreshold);
          _state = _BeatState.followingSlope;
        }
        
        // Reset if no beat for too long
        if (timeSinceLastBeatMs > _invalidReadoutDelayMs) {
          _beatPeriod = 0;
          _lastMaxValue = 0;
        }
        
        _decreaseThreshold();
        break;
        
      case _BeatState.followingSlope:
        if (sample < _threshold) {
          _state = _BeatState.maybeDetected;
        } else {
          _threshold = min(sample, _maxThreshold);
        }
        break;
        
      case _BeatState.maybeDetected:
        if (sample + _stepResiliency < _threshold) {
          // Found a beat!
          _lastMaxValue = sample;
          _state = _BeatState.masking;
          
          if (_tsLastBeat > 0) {
            final deltaMs = timeSinceLastBeatMs;
            if (deltaMs > 0) {
              // Beat stability check - reject if variation is too high
              bool beatStable = true;
              if (_lastBeatIntervalMs > 0 && _beatPeriod > 0) {
                final avgInterval = _beatPeriod;
                final variation = (deltaMs - avgInterval).abs() / avgInterval;
                beatStable = variation <= _maxBeatVariabilityRatio;
              }
              
              if (beatStable) {
                beatDetected = true;
                _lastBeatIntervalMs = deltaMs;
                
                // Low-pass filter the beat period
                if (_beatPeriod == 0) {
                  _beatPeriod = deltaMs;
                } else {
                  _beatPeriod = _bpFilterAlpha * deltaMs + 
                               (1 - _bpFilterAlpha) * _beatPeriod;
                }
              }
            }
          }
          
          _tsLastBeat = _sampleCount;
        } else {
          _state = _BeatState.followingSlope;
        }
        break;
        
      case _BeatState.masking:
        // Non-retriggerable window after beat detection
        if (timeSinceLastBeatMs > _maskingHoldoffMs) {
          _state = _BeatState.waiting;
        }
        _decreaseThreshold();
        break;
    }
    
    return beatDetected;
  }
  
  /// Decrease threshold over time.
  void _decreaseThreshold() {
    if (_lastMaxValue > 0 && _beatPeriod > 0) {
      // Chase toward a fraction of the last max value
      _threshold -= _lastMaxValue * (1 - _thresholdFalloffTarget) /
                   (_beatPeriod / _samplePeriodMs);
    } else {
      // Asymptotic decay
      _threshold *= _thresholdDecayFactor;
    }
    
    if (_threshold < _minThreshold) {
      _threshold = _minThreshold;
    }
  }
  
  /// Update SpO2 calculation (based on MAX30100 reference).
  void _updateSpO2(double irAcValue, double redAcValue, bool beatDetected) {
    // Accumulate squared AC values
    _irAcSqSum += irAcValue * irAcValue;
    _redAcSqSum += redAcValue * redAcValue;
    _spO2SamplesRecorded++;
    
    if (beatDetected) {
      _beatsDetectedNum++;
      
      if (_beatsDetectedNum >= _beatsPerSpO2Calculation) {
        // Calculate SpO2 using log ratio
        if (_spO2SamplesRecorded > 0 && _irAcSqSum > 0 && _redAcSqSum > 0) {
          final acSqRatio = 100.0 * log(_redAcSqSum / _spO2SamplesRecorded) /
                                   log(_irAcSqSum / _spO2SamplesRecorded);
          
          int index = 0;
          if (acSqRatio > 66) {
            index = (acSqRatio - 66).round().clamp(0, _spO2LUT.length - 1);
          } else if (acSqRatio > 50) {
            index = (acSqRatio - 50).round().clamp(0, _spO2LUT.length - 1);
          }
          
          _currentSpO2 = _spO2LUT[index];
        }
        
        _resetSpO2Calculator();
      }
    }
  }
  
  void _resetBeatDetector() {
    _state = _BeatState.init;
    _threshold = _minThreshold;
    _beatPeriod = 0;
    _lastMaxValue = 0;
    _tsLastBeat = 0;
    _lastBeatIntervalMs = 0;
    _initStartSample = _sampleCount;
  }
  
  /// Update amplitude tracking for signal strength validation.
  void _updateAmplitudeTracking(double sample) {
    if (_amplitudeSampleCount == 0) {
      _recentMinIr = sample;
      _recentMaxIr = sample;
    } else {
      if (sample < _recentMinIr) _recentMinIr = sample;
      if (sample > _recentMaxIr) _recentMaxIr = sample;
    }
    _amplitudeSampleCount++;
    
    // Reset window periodically
    if (_amplitudeSampleCount >= _amplitudeWindowSamples) {
      _amplitudeSampleCount = 0;
    }
  }
  
  /// Reset state when finger is removed from sensor.
  void _resetOnNoFinger() {
    _resetBeatDetector();
    _resetSpO2Calculator();
    _bpmHistory.clear();
    _spo2History.clear();
    _lastValidBpm = 0;
    _lastValidSpO2 = 0;
    _recentMinIr = 0;
    _recentMaxIr = 0;
    _amplitudeSampleCount = 0;
  }
  
  void _resetSpO2Calculator() {
    _irAcSqSum = 0;
    _redAcSqSum = 0;
    _spO2SamplesRecorded = 0;
    _beatsDetectedNum = 0;
  }
  
  /// Get the filtered IR buffer for waveform display.
  List<double> getWaveformData() {
    return _irBuffer.toList();
  }
  
  /// Reset all state.
  void reset() {
    _dcIr = 0;
    _dcRed = 0;
    _dcInitialized = false;
    _irBuffer.clear();
    _sampleCount = 0;
    _resetBeatDetector();
    _resetSpO2Calculator();
    _currentSpO2 = 0;
    _bpmHistory.clear();
    _spo2History.clear();
    _lastValidBpm = 0;
    _lastValidSpO2 = 0;
    _recentMinIr = 0;
    _recentMaxIr = 0;
    _amplitudeSampleCount = 0;
    _latestBioData = const BioData();
  }
  
  void dispose() {
    _bioDataController.close();
  }
}
