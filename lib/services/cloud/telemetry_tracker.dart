import 'dart:async';
import '../device/device_service.dart';
import 'cloud_service.dart';

/// Tracks sync status and reports telemetry at minute boundaries.
/// 
/// Monitors [DeviceService] to determine if the user is actively synced
/// (connected + humanDetected). At each minute boundary, if the device
/// was connected at all during that minute, sends a sync_status telemetry
/// event with synced: true if synced for > 30s, or synced: false otherwise.
/// 
/// Supports both MAX30100 (bio sensor) and GY906 (temperature sensor) devices.
/// Sends appropriate vitals based on detected device type.
class TelemetryTracker {
  final DeviceService _deviceService;
  final CloudService _cloudService;

  TelemetryTracker({
    required DeviceService deviceService,
    required CloudService cloudService,
  })  : _deviceService = deviceService,
        _cloudService = cloudService;

  // Subscriptions
  StreamSubscription? _displayStatusSub;
  StreamSubscription? _bioDataSub;
  StreamSubscription? _tempDataSub;
  Timer? _secondTimer;
  Timer? _minuteTimer;

  bool _isInitialized = false;

  // Current state tracking
  bool _wasConnectedThisMinute = false;
  int _syncedSecondsThisMinute = 0;
  final List<int> _bpmReadings = [];
  final List<int> _spo2Readings = [];
  final List<double> _tempReadings = [];
  DateTime _currentMinuteStart = DateTime.now();

  // Cache current status to avoid repeated stream reads
  DeviceDisplayStatus _currentDisplayStatus = DeviceDisplayStatus.searching;
  int _currentBpm = 0;
  int _currentSpo2 = 0;
  double? _currentTemp;

  bool _isDisposed = false;

  /// Initialize the telemetry tracker.
  Future<void> init() async {
    if (_isInitialized) return;

    // Wait for CloudService to be ready
    await _cloudService.init();

    // Listen to display status changes (already includes 2s grace period from DeviceService)
    _displayStatusSub = _deviceService.displayStatus$.listen((status) {
      _currentDisplayStatus = status;
      
      // Track if device was connected at any point this minute
      if (status == DeviceDisplayStatus.synced || 
          status == DeviceDisplayStatus.connected) {
        _wasConnectedThisMinute = true;
      }
    });

    // Listen to bio data for BPM/SpO2 readings (MAX30100)
    _bioDataSub = _deviceService.bioData$.listen((bioData) {
      _currentBpm = bioData.bpm;
      _currentSpo2 = bioData.spo2;
    });
    
    // Listen to temperature data for temperature readings (GY906)
    _tempDataSub = _deviceService.temperatureData$.listen((tempData) {
      _currentTemp = tempData.temperatureCelsius;
    });

    // Initialize current status
    _currentDisplayStatus = _deviceService.currentDisplayStatus;
    final latestBio = _deviceService.latestBioData;
    _currentBpm = latestBio.bpm;
    _currentSpo2 = latestBio.spo2;
    _currentTemp = _deviceService.latestTemperatureData.temperatureCelsius;

    // Align to next minute boundary
    _currentMinuteStart = _alignToMinute(DateTime.now());
    _scheduleMinuteTimer();

    // Start second-by-second tracking
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _onSecondTick();
    });

    _isInitialized = true;
    print('[TelemetryTracker] Initialized, next minute at $_currentMinuteStart');
  }

  /// Align datetime to the next minute boundary.
  DateTime _alignToMinute(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute + 1);
  }

  /// Schedule timer for next minute boundary.
  void _scheduleMinuteTimer() {
    if (_isDisposed) return;

    final now = DateTime.now();
    final delay = _currentMinuteStart.difference(now);
    
    if (delay.isNegative) {
      // Already past the boundary, align to next minute
      _currentMinuteStart = _alignToMinute(now);
      _scheduleMinuteTimer();
      return;
    }

    _minuteTimer?.cancel();
    _minuteTimer = Timer(delay, () {
      if (_isDisposed) return;
      _onMinuteBoundary();
      // Schedule next minute
      _currentMinuteStart = _currentMinuteStart.add(const Duration(minutes: 1));
      _scheduleMinuteTimer();
    });
  }

  /// Called every second to track sync status.
  /// Uses DeviceService's displayStatus which already includes 2s grace period.
  void _onSecondTick() {
    // Check if currently synced (display status already includes grace period)
    final isSynced = _currentDisplayStatus == DeviceDisplayStatus.synced;
    
    if (isSynced) {
      _syncedSecondsThisMinute++;
      
      // Collect readings based on device type
      final deviceType = _deviceService.deviceType;
      
      if (deviceType == DeviceType.max30100) {
        // Collect BPM/SpO2 readings when synced (MAX30100)
        if (_currentBpm > 0) {
          _bpmReadings.add(_currentBpm);
        }
        if (_currentSpo2 > 0) {
          _spo2Readings.add(_currentSpo2);
        }
      } else if (deviceType == DeviceType.gy906) {
        // Collect temperature readings when synced (GY906)
        if (_currentTemp != null) {
          _tempReadings.add(_currentTemp!);
        }
      }
    }

    // Track if device was connected (synced or just connected)
    if (_currentDisplayStatus == DeviceDisplayStatus.synced ||
        _currentDisplayStatus == DeviceDisplayStatus.connected) {
      _wasConnectedThisMinute = true;
    }
  }

  /// Called at each minute boundary.
  void _onMinuteBoundary() {
    // Only send if device was connected at some point this minute
    if (!_wasConnectedThisMinute) {
      _resetMinuteCounters();
      return;
    }

    // Determine sync status: > 30 seconds = synced
    final synced = _syncedSecondsThisMinute > 30;
    final deviceType = _deviceService.deviceType;

    // Calculate averages based on device type
    int? avgBpm;
    int? avgSpo2;
    double? avgTemp;
    
    if (deviceType == DeviceType.max30100) {
      if (_bpmReadings.isNotEmpty) {
        avgBpm = (_bpmReadings.reduce((a, b) => a + b) / _bpmReadings.length).round();
      }
      if (_spo2Readings.isNotEmpty) {
        avgSpo2 = (_spo2Readings.reduce((a, b) => a + b) / _spo2Readings.length).round();
      }
      print('[TelemetryTracker] Minute boundary: synced=$synced '
            '(${_syncedSecondsThisMinute}s), avgBpm=$avgBpm, avgSpo2=$avgSpo2');
    } else if (deviceType == DeviceType.gy906) {
      if (_tempReadings.isNotEmpty) {
        avgTemp = _tempReadings.reduce((a, b) => a + b) / _tempReadings.length;
      }
      print('[TelemetryTracker] Minute boundary: synced=$synced '
            '(${_syncedSecondsThisMinute}s), avgTemp=${avgTemp?.toStringAsFixed(1)}°C');
    } else {
      print('[TelemetryTracker] Minute boundary: synced=$synced '
            '(${_syncedSecondsThisMinute}s), device type unknown');
    }

    // Send telemetry with appropriate vitals
    _cloudService.logSyncStatus(
      timestamp: DateTime.now(),
      synced: synced,
      avgBpm: avgBpm,
      avgSpo2: avgSpo2,
      avgTemp: avgTemp,
    );

    _resetMinuteCounters();
  }

  /// Reset counters for the next minute.
  void _resetMinuteCounters() {
    _wasConnectedThisMinute = false;
    _syncedSecondsThisMinute = 0;
    _bpmReadings.clear();
    _spo2Readings.clear();
    _tempReadings.clear();
  }

  /// Dispose resources.
  void dispose() {
    _isDisposed = true;
    _displayStatusSub?.cancel();
    _bioDataSub?.cancel();
    _tempDataSub?.cancel();
    _secondTimer?.cancel();
    _minuteTimer?.cancel();
  }
}

