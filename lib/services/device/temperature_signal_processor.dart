import 'dart:async';
import 'dart:collection';

/// Processed temperature data from GY906 sensor.
class TemperatureData {
  /// Raw temperature value from sensor (null if sensor error or not present)
  final int? rawTemp;
  
  /// Temperature in Celsius (null if not available)
  final double? temperatureCelsius;
  
  /// Filtered temperature for waveform display
  final double filteredTemp;
  
  /// Whether the sensor is connected and working
  final bool sensorConnected;
  
  /// Whether a human is detected (temperature in valid range: 35.9°C - 41°C)
  final bool humanDetected;
  
  const TemperatureData({
    this.rawTemp,
    this.temperatureCelsius,
    this.filteredTemp = 0.0,
    this.sensorConnected = false,
    this.humanDetected = false,
  });
  
  @override
  String toString() => 'TemperatureData(temp: ${temperatureCelsius?.toStringAsFixed(1)}°C, human: $humanDetected)';
}

/// Processes raw temperature data from GY906 IR temperature sensor.
/// 
/// Human detection is based on temperature being in the physiological range
/// of 35.9°C to 41°C (normal human body temperature range).
class TemperatureSignalProcessor {
  // Human detection thresholds (body temperature range - forearm adjusted)
  static const double _minHumanTemp = 29.7;
  static const double _maxHumanTemp = 41.0;
  
  // Temperature buffer for waveform display (5 seconds at ~100Hz)
  static const int _bufferSize = 500;
  final Queue<double> _tempBuffer = Queue<double>();
  
  // History for averaging and stability
  final Queue<double> _tempHistory = Queue<double>();
  static const int _historySize = 30; // ~300ms at 100Hz
  
  // Sustained valid reading check
  int _consecutiveValidSamples = 0;
  static const int _sustainedThreshold = 50; // 0.5 seconds
  
  // Stream controller
  final StreamController<TemperatureData> _dataController = StreamController.broadcast();
  Stream<TemperatureData> get temperatureData$ => _dataController.stream;
  
  // Latest values for synchronous access
  TemperatureData _latestData = const TemperatureData();
  TemperatureData get latestData => _latestData;
  
  /// Convert raw sensor value to Celsius.
  /// Formula from GY906 datasheet: (rawValue * 0.02) - 273.15
  static double rawToCelsius(int raw) => (raw * 0.02) - 273.15;
  
  /// Process raw temperature value from the sensor.
  void process(int rawTemp) {
    // Handle sensor error (0 typically means no reading)
    if (rawTemp == 0) {
      _latestData = const TemperatureData(
        sensorConnected: true,
        humanDetected: false,
      );
      _dataController.add(_latestData);
      return;
    }
    
    // Convert to Celsius
    final tempCelsius = rawToCelsius(rawTemp);
    
    // Store for waveform display
    _tempBuffer.addLast(tempCelsius);
    while (_tempBuffer.length > _bufferSize) {
      _tempBuffer.removeFirst();
    }
    
    // Store in history for averaging
    _tempHistory.addLast(tempCelsius);
    while (_tempHistory.length > _historySize) {
      _tempHistory.removeFirst();
    }
    
    // Check if temperature is in human range
    final inHumanRange = tempCelsius >= _minHumanTemp && tempCelsius <= _maxHumanTemp;
    
    if (inHumanRange) {
      _consecutiveValidSamples++;
    } else {
      _consecutiveValidSamples = 0;
    }
    
    // Human detected: in range AND sustained for threshold duration
    final humanDetected = inHumanRange && _consecutiveValidSamples >= _sustainedThreshold;
    
    _latestData = TemperatureData(
      rawTemp: rawTemp,
      temperatureCelsius: tempCelsius,
      filteredTemp: tempCelsius,
      sensorConnected: true,
      humanDetected: humanDetected,
    );
    
    _dataController.add(_latestData);
  }
  
  /// Get the temperature buffer for waveform display.
  List<double> getWaveformData() {
    return _tempBuffer.toList();
  }
  
  /// Get average temperature from history.
  double? getAverageTemperature() {
    if (_tempHistory.isEmpty) return null;
    final sum = _tempHistory.reduce((a, b) => a + b);
    return sum / _tempHistory.length;
  }
  
  /// Reset all state.
  void reset() {
    _tempBuffer.clear();
    _tempHistory.clear();
    _consecutiveValidSamples = 0;
    _latestData = const TemperatureData();
  }
  
  void dispose() {
    _dataController.close();
  }
}
