import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;

import 'bluetooth_service.dart';
import 'bio_signal_processor.dart';
import 'temperature_signal_processor.dart';
export 'bluetooth_service.dart' show BluetoothUserAction, BluetoothUserActionType;
export 'bio_signal_processor.dart' show BioData;
export 'temperature_signal_processor.dart' show TemperatureData;


/// High-level device state.
enum DeviceConnectionState {
  disconnected,
  searching,
  connecting,
  connected,
}

/// UI-facing display status.
enum DeviceDisplayStatus {
  synced,     // Connected AND human detected
  connected,  // Connected but no human detected
  waiting,    // Disconnected but has saved ID
  searching,  // Disconnected and no saved ID
}

/// Type of connected sensor device.
/// Determined by first packet size and sticky until disconnect.
enum DeviceType {
  unknown,   // Not yet determined
  max30100,  // Pulse oximeter (16-byte packets)
  gy906,     // Temperature sensor (14-byte packets)
}

abstract class DeviceEvent {}

class ShakeEvent extends DeviceEvent {}


/// Abstraction layer for the "Smart Device".
///
/// Consumes low-level [BluetoothService] and exposes high-level domain objects
/// (TelemetryData, ConnectionState) to the rest of the application.
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();

  factory DeviceService() => _instance;

  DeviceService._internal();

  final BluetoothService _bluetooth = BluetoothService();

  // --- State & Streams ---

  final StreamController<DeviceConnectionState> _connectionStateController =
      StreamController.broadcast();
  Stream<DeviceConnectionState> get connectionState$ =>
      _connectionStateController.stream;

  final StreamController<DeviceDisplayStatus> _displayStatusController =
      StreamController.broadcast();
  Stream<DeviceDisplayStatus> get displayStatus$ =>
      _displayStatusController.stream;

  final StreamController<TelemetryData> _telemetryController =
      StreamController.broadcast();
  Stream<TelemetryData> get telemetry$ => _telemetryController.stream;

  final StreamController<DeviceEvent> _eventsController =
      StreamController.broadcast();
  Stream<DeviceEvent> get events$ => _eventsController.stream;

  DeviceConnectionState _currentState = DeviceConnectionState.disconnected;
  DeviceConnectionState get currentState => _currentState;
  
  DeviceDisplayStatus? _lastEmittedStatus;

  void _emitDisplayStatus(DeviceDisplayStatus status) {
    if (_lastEmittedStatus != status) {
      _lastEmittedStatus = status;
      _displayStatusController.add(status);
    }
  }

  int _activeMinigames = 0;
  bool get _isMinigameRunning => _activeMinigames > 0;

  void registerMinigameStart() {
    _activeMinigames++;
    if (_currentState == DeviceConnectionState.connected) {
      _emitDisplayStatus(currentDisplayStatus);
    }
  }

  void registerMinigameEnd() {
    if (_activeMinigames > 0) {
      _activeMinigames--;
      if (_currentState == DeviceConnectionState.connected) {
        _emitDisplayStatus(currentDisplayStatus);
      }
    }
  }
  
  // Grace period for sync status (12 seconds to accommodate 10s barrage OFF phase)
  static const Duration _syncGracePeriod = Duration(seconds: 12);
  Timer? _syncGraceTimer;
  bool _inSyncGracePeriod = false;
  bool _wasHumanDetected = false;
  
  // Debounce buffer - require consecutive "no human" samples before triggering grace
  static const int _noHumanDebounceThreshold = 20; // ~200ms at 100Hz
  int _consecutiveNoHumanSamples = 0;
  
  // Liveness tracking - require recent telemetry data to consider "connected"
  static const Duration _livenessTimeout = Duration(seconds: 3);
  DateTime? _lastTelemetryTime;
  
  // Barrage active time sliding window (60 seconds)
  final Queue<bool> _humanDetectionHistory = Queue<bool>();
  Timer? _historyTimer;
  
  /// Check if we have received telemetry data recently (liveness check).
  bool get _hasRecentTelemetry {
    if (_lastTelemetryTime == null) return false;
    return DateTime.now().difference(_lastTelemetryTime!) < _livenessTimeout;
  }
  
  DeviceDisplayStatus get currentDisplayStatus {
    if (_currentState == DeviceConnectionState.connected) {
      // Require recent telemetry data (IMU liveness check) to truly be "connected"
      if (!_hasRecentTelemetry) {
        // No recent data - we're waiting for connection to establish
        final hasSaved = _bluetooth.getSavedDeviceId() != null;
        return hasSaved ? DeviceDisplayStatus.waiting : DeviceDisplayStatus.searching;
      }
      
      // We have recent data - check if human is detected via appropriate sensor
      // Grace period only applies if we previously had REAL synced status with actual data
      final humanDetectedReal = _isHumanDetected();
      final isDebouncing = _wasHumanDetected && !_inSyncGracePeriod && _consecutiveNoHumanSamples < _noHumanDebounceThreshold;
      final humanDetected = humanDetectedReal || isDebouncing;
      
      // Calculate active time in the last 60 seconds
      int activeSeconds = _humanDetectionHistory.where((detected) => detected).length;
      
      // We expect up to 30s of active time in a full 60s window (due to 10s ON / 10s OFF).
      // If the window is still filling (length < 60), we scale the requirement.
      // Require 33% active time over the trailing window to provide proper leeway.
      int windowSize = _humanDetectionHistory.length;
      int requiredSeconds = windowSize > 0 ? (windowSize * 0.33).round() : 0;
      bool barrageMet = activeSeconds >= requiredSeconds;
      
      if (_isMinigameRunning || (barrageMet && (humanDetected || (_inSyncGracePeriod && _wasHumanDetected)))) {
        return DeviceDisplayStatus.synced;
      }
      return DeviceDisplayStatus.connected;
    }
    // If not connected, check if we are "waiting" (saved ID exists) or "searching"
    final hasSaved = _bluetooth.getSavedDeviceId() != null;
    return hasSaved ? DeviceDisplayStatus.waiting : DeviceDisplayStatus.searching;
  }
  
  /// Check if human is detected based on device type.
  bool _isHumanDetected() {
    switch (_deviceType) {
      case DeviceType.max30100:
        return _bioProcessor.latestBioData.humanDetected;
      case DeviceType.gy906:
        return _tempProcessor.latestData.humanDetected;
      case DeviceType.unknown:
        return false;
    }
  }

  StreamSubscription? _rawSub;
  StreamSubscription? _bleConnectionSub;
  StreamSubscription? _nativeConnectionSub;
  StreamSubscription? _bioSub;
  StreamSubscription? _tempSub;

  // Device type detection (sticky - determined by first packet)
  DeviceType _deviceType = DeviceType.unknown;
  DeviceType get deviceType => _deviceType;

  // Bio signal processing (MAX30100)
  final BioSignalProcessor _bioProcessor = BioSignalProcessor();
  Stream<BioData> get bioData$ => _bioProcessor.bioData$;
  BioData get latestBioData => _bioProcessor.latestBioData;
  List<double> get waveformData => _bioProcessor.getWaveformData();
  
  // Temperature signal processing (GY906)
  final TemperatureSignalProcessor _tempProcessor = TemperatureSignalProcessor();
  Stream<TemperatureData> get temperatureData$ => _tempProcessor.temperatureData$;
  TemperatureData get latestTemperatureData => _tempProcessor.latestData;
  List<double> get temperatureWaveformData => _tempProcessor.getWaveformData();

  // Configuration
  double _shakeThreshold = 2.5;

  // --- Initialization ---

  Future<void> init() async {
    // Ensure BluetoothService is initialized if not already
    await _bluetooth.init();

    // Listen to native connected status for robust state
    // We prioritize native status as it survives UI restarts
    _nativeConnectionSub = _bluetooth.nativeConnected$.listen((isConnected) {
       if (isConnected) {
         _updateState(DeviceConnectionState.connected);
       } else {
         if (_currentState == DeviceConnectionState.connected) {
           _updateState(DeviceConnectionState.disconnected);
           // Reset device type on disconnect (will be re-detected on next packet)
           _deviceType = DeviceType.unknown;
           _bioProcessor.reset();
           _tempProcessor.reset();
           // Reset liveness and grace period state
           _lastTelemetryTime = null;
           _inSyncGracePeriod = false;
           _wasHumanDetected = false;
           _syncGraceTimer?.cancel();
         }
       }
    });

    // Listen to device connection stream for more granular updates if needed
    _bleConnectionSub = _bluetooth.connectedDevice$.listen((device) {
       // Optional: could use this to access specific device details
    });

    // Consume raw bytes and parse into TelemetryData
    _rawSub = _bluetooth.incomingRaw$.listen((bytes) {
      final data = TelemetryData.fromBytes(bytes);
      if (data != null) {
        // Update liveness timestamp on every valid packet (IMU data = device alive)
        _lastTelemetryTime = DateTime.now();
        
        _telemetryController.add(data);
        _checkForHighLevelEvents(data);
        
        // Detect device type from first packet (sticky)
        if (_deviceType == DeviceType.unknown) {
          if (bytes.length == 16) {
            _deviceType = DeviceType.max30100;
          } else if (bytes.length == 14) {
            _deviceType = DeviceType.gy906;
          }
        }
        
        // Route to appropriate processor based on device type
        if (data.rawIr != null && data.rawRed != null) {
          _bioProcessor.process(data.rawIr!, data.rawRed!);
        } else if (data.rawTemp != null) {
          _tempProcessor.process(data.rawTemp!);
        }
        
        // Update display status since liveness may have changed
        _emitDisplayStatus(currentDisplayStatus);
      }
    });
    
    // Listen to bio data changes to update display status with grace period
    _bioSub = _bioProcessor.bioData$.listen((bioData) {
      _handleHumanDetectionChange(bioData.humanDetected);
    });
    
    // Listen to temperature data changes to update display status
    _tempSub = _tempProcessor.temperatureData$.listen((tempData) {
      _handleHumanDetectionChange(tempData.humanDetected);
    });
    
    // Initialize barrage evaluation timer
    _historyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentState == DeviceConnectionState.connected && _hasRecentTelemetry) {
        _humanDetectionHistory.addLast(_isHumanDetected());
        if (_humanDetectionHistory.length > 60) {
          _humanDetectionHistory.removeFirst(); // maintain 60-second window
        }
        _emitDisplayStatus(currentDisplayStatus);
      } else if (_humanDetectionHistory.isNotEmpty) {
        // clear history on disconnect
        _humanDetectionHistory.clear();
      }
    });
    
    // Initial emission
    _emitDisplayStatus(currentDisplayStatus);
  }
  
  /// Handle human detection changes with grace period and debounce.
  void _handleHumanDetectionChange(bool humanDetected) {
    if (humanDetected) {
      // Human detected - cancel any pending grace timer, reset debounce, and update
      _syncGraceTimer?.cancel();
      _inSyncGracePeriod = false;
      _consecutiveNoHumanSamples = 0; // Reset debounce counter
      _wasHumanDetected = true;
      _emitDisplayStatus(currentDisplayStatus);
    } else {
      // Human not detected - increment debounce counter
      _consecutiveNoHumanSamples++;
      
      if (_wasHumanDetected && !_inSyncGracePeriod) {
        // Was synced, check if debounce threshold met
        if (_consecutiveNoHumanSamples >= _noHumanDebounceThreshold) {
          // Debounce threshold met - start grace period
          _inSyncGracePeriod = true;
          _syncGraceTimer?.cancel();
          _syncGraceTimer = Timer(_syncGracePeriod, () {
            // Grace period expired
            _inSyncGracePeriod = false;
            _wasHumanDetected = false;
            _emitDisplayStatus(currentDisplayStatus);
          });
        }
        // Don't emit yet - either still in debounce or grace period
      } else if (!_wasHumanDetected) {
        // Never was synced, just emit current status
        _emitDisplayStatus(currentDisplayStatus);
      }
      // If already in grace period, do nothing - let the timer handle it
    }
  }

  void _updateState(DeviceConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(newState);
      // Also update display status
      _emitDisplayStatus(currentDisplayStatus);
    }
  }

  // --- High Level Logic ---

  void updateShakeThreshold(double val) {
    _shakeThreshold = val;
  }

  void _checkForHighLevelEvents(TelemetryData data) {
    if (data.magnitude > _shakeThreshold) {
      _eventsController.add(ShakeEvent());
    }
  }

  // --- Public API ---

  Future<void> connectToSavedDevice() async {
    // This logic logic resides mainly in BluetoothService.init() which auto-reconnects.
    // However, if we want to manually trigger a retry:
    final savedId = _bluetooth.getSavedDeviceId();
    if (savedId != null && _currentState != DeviceConnectionState.connected) {
       _updateState(DeviceConnectionState.searching);
       // We can rely on system auto-reconnect or manual user action via settings
    }
  }

  Future<void> disconnect() async {
    await _bluetooth.disconnect();
  }

  Future<void> forget() async {
    await _bluetooth.forget();
  }
  
  // Passthrough for scanning (needed by SettingsPage)
  Stream<List<ScanResult>> get foundDevices$ => _bluetooth.foundDevices$;
  
  Future<void> startScan({Duration? timeout}) => _bluetooth.startScan(timeout: timeout);
  Future<void> stopScan() => _bluetooth.stopScan();
  
  Future<void> connect(BluetoothDevice device) async {
    _updateState(DeviceConnectionState.connecting);
    await _bluetooth.connect(device);
  }

  // Debug/Dev tools passthrough
  Map<String, String> get debugInfo => _bluetooth.debugInfo;
  Stream<List<int>> get incomingRaw$ => _bluetooth.incomingRaw$;
  Stream<String> get incomingData$ => _bluetooth.incomingData$;
  Stream<BluetoothDevice?> get connectedDevice$ => _bluetooth.connectedDevice$;
  Future<void> requestNativeStatus() => _bluetooth.requestNativeStatus();

  // Passthroughs for Settings/Permissions
  Stream<BluetoothUserAction> get userAction$ => _bluetooth.userAction$;
  Future<bool> performEnableBluetooth() => _bluetooth.performEnableBluetooth();
  Future<bool> performRequestPermissions() => _bluetooth.performRequestPermissions();
  Map<String, bool> get permissionStatuses => _bluetooth.permissionStatuses;

  /// Called when the app returns from background/lock screen.
  /// Re-attaches the severed EventChannel and resets stale Dart state
  /// so the monitoring pipeline recovers immediately.
  Future<void> onAppResumed() async {
    // Reset liveness so we don't report stale "connected" until fresh packets arrive
    _lastTelemetryTime = null;
    // Clear stale barrage window data
    _humanDetectionHistory.clear();
    _inSyncGracePeriod = false;
    _wasHumanDetected = false;
    _syncGraceTimer?.cancel();
    _consecutiveNoHumanSamples = 0;
    // Emit current display status (will be waiting/searching until data flows)
    _emitDisplayStatus(currentDisplayStatus);
    // Re-attach native event stream and request fresh status from native service
    await _bluetooth.reattachNativeEventStream();
  }


  void dispose() {
    _rawSub?.cancel();
    _bleConnectionSub?.cancel();
    _nativeConnectionSub?.cancel();
    _bioSub?.cancel();
    _tempSub?.cancel();
    _syncGraceTimer?.cancel();
    _historyTimer?.cancel();
    _bioProcessor.dispose();
    _tempProcessor.dispose();
    _connectionStateController.close();
    _displayStatusController.close();
    _telemetryController.close();
    _eventsController.close();
  }
}

/// Decoded IMU telemetry data from the M5-IMU-Sensor device.
/// 
/// The device sends 12, 14, or 16 bytes:
/// - 12 bytes: 6 × int16 little-endian (IMU only)
/// - 14 bytes: 7 × int16 little-endian (IMU + GY906 temperature sensor)
/// - 16 bytes: 8 × int16 little-endian (IMU + MAX30100 bio sensor)
/// 
/// IMU Data:
/// - Accelerometer (ax, ay, az): raw value ÷ 1000 = g
/// - Gyroscope (gx, gy, gz): raw value ÷ 10 = deg/s
/// 
/// GY906 Temperature Data (14-byte payload):
/// - rawTemp: Raw temperature value
/// - To convert to Celsius: (rawTemp * 0.02) - 273.15
/// 
/// MAX30100 Bio Sensor Data (16-byte payload):
/// - rawIr: Raw infrared light intensity (or null if not present)
/// - rawRed: Raw red LED light intensity (or null if not present)
class TelemetryData {
  /// Accelerometer X-axis in g
  final double ax;
  /// Accelerometer Y-axis in g
  final double ay;
  /// Accelerometer Z-axis in g
  final double az;
  /// Gyroscope X-axis in deg/s
  final double gx;
  /// Gyroscope Y-axis in deg/s
  final double gy;
  /// Gyroscope Z-axis in deg/s
  final double gz;
  /// Raw IR value from bio sensor (null if not present, 65535 if sensor error)
  final int? rawIr;
  /// Raw RED value from bio sensor (null if not present, 65535 if sensor error)
  final int? rawRed;
  /// Raw temperature value from GY906 sensor (null if not present)
  final int? rawTemp;

  const TelemetryData({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    this.rawIr,
    this.rawRed,
    this.rawTemp,
  });

  /// Magnitude of the acceleration vector.
  /// Useful for motion detection (e.g., jump threshold in games).
  /// At rest, this should be ~1.0g (gravity).
  double get magnitude => sqrt(ax * ax + ay * ay + az * az);
  
  /// Temperature in Celsius (null if not a GY906 packet).
  /// Only valid when rawTemp is not null.
  double? get temperatureCelsius => rawTemp != null 
      ? TemperatureSignalProcessor.rawToCelsius(rawTemp!) 
      : null;

  /// Factory to decode 12, 14, or 16-byte payload.
  /// Returns null if bytes are invalid.
  static TelemetryData? fromBytes(List<int> bytes) {
    // Support 12-byte (IMU only), 14-byte (IMU + Temp), and 16-byte (IMU + Bio) payloads
    if (bytes.length != 12 && bytes.length != 14 && bytes.length != 16) return null;
    
    try {
      final data = Uint8List.fromList(bytes);
      final byteData = ByteData.sublistView(data);
      
      // Read 6 × int16 little-endian for IMU
      final rawAx = byteData.getInt16(0, Endian.little);
      final rawAy = byteData.getInt16(2, Endian.little);
      final rawAz = byteData.getInt16(4, Endian.little);
      final rawGx = byteData.getInt16(6, Endian.little);
      final rawGy = byteData.getInt16(8, Endian.little);
      final rawGz = byteData.getInt16(10, Endian.little);
      
      // Read sensor data based on payload size
      int? rawIr;
      int? rawRed;
      int? rawTemp;
      
      if (bytes.length == 16) {
        // MAX30100: Bio values are UNSIGNED 16-bit (0-65535)
        // 65535 (0xFFFF) indicates sensor error
        rawIr = byteData.getUint16(12, Endian.little);
        rawRed = byteData.getUint16(14, Endian.little);
      } else if (bytes.length == 14) {
        // GY906: Temperature value is UNSIGNED 16-bit
        rawTemp = byteData.getUint16(12, Endian.little);
      }
      
      return TelemetryData(
        ax: rawAx / 1000.0,
        ay: rawAy / 1000.0,
        az: rawAz / 1000.0,
        gx: rawGx / 10.0,
        gy: rawGy / 10.0,
        gz: rawGz / 10.0,
        rawIr: rawIr,
        rawRed: rawRed,
        rawTemp: rawTemp,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() {
    final bio = rawIr != null ? ' IR:$rawIr RED:$rawRed' : '';
    final temp = rawTemp != null ? ' TEMP:${temperatureCelsius?.toStringAsFixed(1)}°C' : '';
    return 'A:(${ax.toStringAsFixed(2)}, ${ay.toStringAsFixed(2)}, ${az.toStringAsFixed(2)}) '
           'G:(${gx.toStringAsFixed(1)}, ${gy.toStringAsFixed(1)}, ${gz.toStringAsFixed(1)})$bio$temp';
  }
}


