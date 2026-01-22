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

/// DC Remover filter from MAX30100 library
/// http://sam-koblenski.blogspot.de/2015/11/everyday-dsp-for-programmers-dc-and.html
class DCRemover {
  final double alpha;
  double _dcw = 0.0;

  DCRemover({this.alpha = 0.95});

  double step(double x) {
    final double olddcw = _dcw;
    _dcw = x + alpha * _dcw;
    return _dcw - olddcw;
  }

  double getDCW() {
    return _dcw;
  }
  
  void reset() {
    _dcw = 0.0;
  }
}

/// Low pass butterworth filter order=1 alpha1=0.1
/// Fs=100Hz, Fc=6Hz
/// http://www.schwietering.com/jayduino/filtuino/
class FilterBuLp1 {
  final List<double> _v = [0.0, 0.0];

  double step(double x) {
    _v[0] = _v[1];
    _v[1] = (2.452372752527856026e-1 * x) + (0.50952544949442879485 * _v[0]);
    return _v[0] + _v[1];
  }
  
  void reset() {
    _v[0] = 0.0;
    _v[1] = 0.0;
  }
}

/// Processes raw bio-sensor data from MAX30100 pulse oximeter.
/// 
/// Based on the reference implementation from Arduino-MAX30100 library.
/// Uses state machine for beat detection and log-ratio for SpO2.
class BioSignalProcessor {
  // Timing configuration (updated for 100Hz)
  static const double _sampleRate = 100.0;
  static const double _samplePeriodMs = 1000.0 / _sampleRate; // 10ms
  
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
  // When no finger, Raw IR is low. With finger/wrist, Raw IR is high.
  static const int _minRawIrForFinger = 5000;
  
  // Signal amplitude validation - minimum peak-to-peak amplitude to consider valid
  // The LP filtered signal might be smaller, adjusted accordingly
  static const double _minPeakToPeakAmplitude = 2.0; 
  
  // SpO2 physiological range (wrist readings stay >90%)
  static const int _minPhysiologicalSpO2 = 70;
  static const int _maxPhysiologicalSpO2 = 100;
  
  // Filters
  final DCRemover _dcFilterIr = DCRemover();
  final DCRemover _dcFilterRed = DCRemover();
  final FilterBuLp1 _lpfIr = FilterBuLp1();
  
  bool _initialized = false;
  
  // Beat detector state
  _BeatState _state = _BeatState.init;
  double _threshold = _minThreshold;
  double _beatPeriod = 0;
  double _lastMaxValue = 0;
  int _tsLastBeat = 0; // In sample counts
  int _sampleCount = 0;
  int _initStartSample = 0;
  
  // Waveform buffer
  final Queue<double> _irBuffer = Queue<double>();
  static const int _bufferSeconds = 5;
  
  // Amplitude tracking for finger detection
  double _recentMinIr = 0;
  double _recentMaxIr = 0;
  int _amplitudeSampleCount = 0;
  static const int _amplitudeWindowSamples = 100; // 1 second at 100Hz
  
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
    
    // === Signal Processing Pipeline ===
    // 1. DC Removal
    final double acIr = _dcFilterIr.step(rawIr.toDouble());
    final double acRed = _dcFilterRed.step(rawRed.toDouble());
    
    // 2. Low Pass Filtering (Butterworth) - Critical for noise rejection
    // Invert input because pulse is a dip in IR (absorption)
    final double filteredIr = _lpfIr.step(-acIr);
    
    // === Finger/Wrist Presence Detection ===
    // Simple check on Raw IR magnitude
    final fingerDetected = rawIr > _minRawIrForFinger;
    
    // Track amplitude of the FILTERED signal for additional validation
    _updateAmplitudeTracking(filteredIr);
    final amplitude = _recentMaxIr - _recentMinIr;
    final signalStrong = amplitude >= _minPeakToPeakAmplitude;
    
    // Soft reset if no finger (just state, but don't stop processing stream completely if we want to see noise)
    // Actually, if we don't reset, the state machine might drift. 
    // But the user requested "no longer need the sensor to pause".
    // Let's Keep processing but flag fingerDetected as false if rawIr is low.
    
    // Optimization: If rawIr is extremely low (e.g. < 1000), it's definitely air.
    // If it's borderline, we process.
    if (rawIr < 1000) {
      _resetOnNoFinger();
      _latestBioData = BioData(
        rawIr: rawIr,
        rawRed: rawRed,
        filteredIr: filteredIr,
        bpm: 0,
        spo2: 0,
        sensorConnected: true,
        fingerDetected: false, // Explicitly false
        humanDetected: false,
      );
      _bioDataController.add(_latestBioData);
      return;
    }
    
    if (!_initialized) {
        _initialized = true;
        _initStartSample = _sampleCount;
    }
    
    // === Store for waveform display ===
    final maxBufferSize = (_sampleRate * _bufferSeconds).toInt();
    _irBuffer.addLast(filteredIr);
    while (_irBuffer.length > maxBufferSize) {
      _irBuffer.removeFirst();
    }
    
    // === Anti-Freeze / Stale Data Protection ===
    // If no beat detected for too long, flush history to prevent "sticking" to old values
    final timeSinceLastBeatMs = (_sampleCount - _tsLastBeat) * _samplePeriodMs;
    if (_tsLastBeat > 0 && timeSinceLastBeatMs > 5000) {
      _flushHistory();
    }
    
    // === Beat Detection (State Machine) ===
    // The state machine will naturally reset if no valid beats found
    final beatDetected = _checkForBeat(filteredIr);
    
    // === SpO2 Calculation ===
    _updateSpO2(acIr, acRed, beatDetected);
    
    // === Calculate BPM from beat period ===
    int bpm = 0;
    if (_beatPeriod > 0) {
      // beatPeriod is in ms
      bpm = (60000.0 / _beatPeriod).round().clamp(30, 220);
    }
    
    // Update history for valid values (only if signal is strong)
    bool isValidSample = false;
    
    if (signalStrong && bpm >= _minBpmForHuman && bpm <= _maxBpmForHuman) {
      _lastValidBpm = bpm;
      _bpmHistory.addLast(bpm);
      while (_bpmHistory.length > 30) _bpmHistory.removeFirst();
      isValidSample = true;
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

    // Track consecutive valid samples to filter out momentary noise bursts
    if (isValidSample) {
      _consecutiveValidSamples++;
    } else {
      _consecutiveValidSamples = 0;
    }
    
    // Display last valid values (persistence) - only if signal still strong
    final displayBpm = (signalStrong && bpm > 0) ? bpm : (signalStrong ? _lastValidBpm : 0);
    final displaySpO2 = (signalStrong && validSpO2 > 0) ? validSpO2 : (signalStrong ? _lastValidSpO2 : 0);
    
    // False Positive Check: BPM Variance
    // If the BPM is jumping around wildly (e.g. 60 -> 140 -> 60), it's likely noise/motion artifact
    final bpmStdDev = _calculateBpmStdDev();
    final isBpmStable = bpmStdDev < 20.0; // Allow some variance (arrhythmia/adjustment) but not chaos
    
    // Human detection requirements:
    // 1. Signal amplitude is strong (handled by signalStrong)
    // 2. Sufficient history needed (at least 3 BPM samples)
    // 3. SpO2 history exists
    // 4. Current displayed BPM is reasonable
    // 5. [NEW] Signal has been valid for a sustained period (> 1 second)
    // 6. [NEW] BPM is stable (low variance)
    final humanDetected = signalStrong &&
                          _bpmHistory.length >= 3 && 
                          _spo2History.isNotEmpty &&
                          displayBpm >= _minBpmForHuman && 
                          displayBpm <= _maxBpmForHuman &&
                          _consecutiveValidSamples > 100 && // > 1 second at 100Hz
                          isBpmStable;

    _latestBioData = BioData(
      rawIr: rawIr,
      rawRed: rawRed,
      filteredIr: filteredIr,
      bpm: displayBpm,
      spo2: displaySpO2,
      sensorConnected: true,
      fingerDetected: fingerDetected, // Uses the robust raw check
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
          beatDetected = true;
          
          if (_tsLastBeat > 0) {
            final deltaMs = timeSinceLastBeatMs;
            if (deltaMs > 0) {
              // Low-pass filter the beat period
              if (_beatPeriod == 0) {
                _beatPeriod = deltaMs;
              } else {
                _beatPeriod = _bpFilterAlpha * deltaMs + 
                             (1 - _bpFilterAlpha) * _beatPeriod;
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
    _dcFilterIr.reset();
    _dcFilterRed.reset();
    _lpfIr.reset();
    _bpmHistory.clear();
    _spo2History.clear();
    _lastValidBpm = 0;
    _lastValidSpO2 = 0;
    _recentMinIr = 0;
    _recentMaxIr = 0;
    _amplitudeSampleCount = 0;
    _initialized = false;
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
  
  // Track consecutive valid samples to ensure signal stability before confirming human
  int _consecutiveValidSamples = 0;

  void _flushHistory() {
    _bpmHistory.clear();
    _spo2History.clear();
    _lastValidBpm = 0;
    _lastValidSpO2 = 0;
    _consecutiveValidSamples = 0;
    // We also reset the beat detector heavily to force resync
    _resetBeatDetector();
  }

  double _calculateBpmStdDev() {
    if (_bpmHistory.isEmpty) return 0.0;
    
    double sum = 0;
    for (var b in _bpmHistory) sum += b;
    double mean = sum / _bpmHistory.length;
    
    double varianceSum = 0;
    for (var b in _bpmHistory) {
      varianceSum += (b - mean) * (b - mean);
    }
    
    return sqrt(varianceSum / _bpmHistory.length);
  }
  
  /// Reset all state.
  void reset() {
    _irBuffer.clear();
    _sampleCount = 0;
    _resetOnNoFinger();
    _latestBioData = const BioData();
  }
  
  void dispose() {
    _bioDataController.close();
  }
}
