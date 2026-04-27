import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;

import 'bluetooth_service.dart';
import 'bio_signal_processor.dart';
import 'temperature_signal_processor.dart';
import 'device_status_aggregator.dart';
import '../../game/models/telemetry_data.dart';
export 'bluetooth_service.dart' show BluetoothUserAction, BluetoothUserActionType;
export 'bio_signal_processor.dart' show BioData;
export 'temperature_signal_processor.dart' show TemperatureData;
export '../../game/models/telemetry_data.dart';


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
  DeviceService();

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
  
  // Liveness tracking - require recent telemetry data to consider "connected"
  static const Duration _livenessTimeout = Duration(seconds: 3);
  DateTime? _lastTelemetryTime;
  bool _awaitingFreshTelemetry = true;

  /// Check if we have received telemetry data recently (liveness check).
  bool get _hasRecentTelemetry {
    if (_lastTelemetryTime == null) return false;
    return DateTime.now().difference(_lastTelemetryTime!) < _livenessTimeout;
  }

  DeviceDisplayStatus _staleDisplayStatus() {
    final hasSaved = _bluetooth.getSavedDeviceId() != null;
    return hasSaved ? DeviceDisplayStatus.waiting : DeviceDisplayStatus.searching;
  }

  bool get _hasFreshTelemetryForUi {
    return !_awaitingFreshTelemetry && _hasRecentTelemetry;
  }
  
  late final DeviceStatusAggregator _statusAggregator = DeviceStatusAggregator(
    baseStatusProvider: () {
      if (_currentState == DeviceConnectionState.connected) return DeviceDisplayStatus.connected;
      return _staleDisplayStatus();
    },
    staleStatusProvider: _staleDisplayStatus,
    isHumanDetectedProvider: _isHumanDetected,
    isMinigameRunningProvider: () => _activeMinigames > 0,
    hasRecentTelemetryProvider: () => _hasFreshTelemetryForUi,
  );

  DeviceDisplayStatus get currentDisplayStatus => _statusAggregator.currentDisplayStatus;
  
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
  StreamSubscription? _nativeHumanSub;
  StreamSubscription? _nativeBpmSub;
  StreamSubscription? _nativeSpo2Sub;

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
    // 1. Attach listeners BEFORE initializing BluetoothService to capture initial state emissions
    
    // Listen to native human detection and vitals to pre-seed bio processor
    _nativeHumanSub = _bluetooth.nativeHumanDetected$.listen((isDetected) {
      if (isDetected && _deviceType == DeviceType.max30100) {
        // BioProcessor will be pre-seeded when BPM/SpO2 arrive
      }
    });

    _nativeBpmSub = _bluetooth.nativeBpm$.listen((bpm) {
      if (bpm > 0 && _deviceType == DeviceType.max30100) {
        _bioProcessor.preSeed(bpm, _bioProcessor.latestBioData.spo2);
      }
    });

    _nativeSpo2Sub = _bluetooth.nativeSpo2$.listen((spo2) {
      if (spo2 > 0 && _deviceType == DeviceType.max30100) {
        _bioProcessor.preSeed(_bioProcessor.latestBioData.bpm, spo2);
      }
    });

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
           _awaitingFreshTelemetry = true;
           _statusAggregator.reset();
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
        _awaitingFreshTelemetry = false;
        
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
      _statusAggregator.handleHumanDetectionChange(bioData.humanDetected);
    });
    
    // Listen to temperature data changes to update display status
    _tempSub = _tempProcessor.temperatureData$.listen((tempData) {
      _statusAggregator.handleHumanDetectionChange(tempData.humanDetected);
    });
    
    _statusAggregator.status$.listen((status) {
      _emitDisplayStatus(status);
    });

    // 2. Now initialize BluetoothService (triggers initial broadcasts)
    await _bluetooth.init();
    
    // 3. Re-verify initial state if listeners were attached too late for some reason
    // or to handle the synchronous state stored in BluetoothService
    if (_bluetooth.isNativeConnected) {
      _updateState(DeviceConnectionState.connected);
    }
    
    if (_bluetooth.isNativeHumanDetected && _deviceType == DeviceType.max30100) {
      _bioProcessor.preSeed(_bluetooth.nativeBpm, _bluetooth.nativeSpo2);
    }
    
    // Initial emission
    _emitDisplayStatus(currentDisplayStatus);
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
    _awaitingFreshTelemetry = true;
    _statusAggregator.reset();
    // Emit current display status (will be waiting/searching until data flows)
    _emitDisplayStatus(currentDisplayStatus);
    // Re-attach native event stream and request fresh status from native service
    await _bluetooth.reattachNativeEventStream();
  }

  // --- Last Reading API (for display during transmission pauses) ---

  /// Get the last valid bio reading (with BPM and SpO2 values).
  /// Returns null if no valid reading is available.
  BioData? get lastValidBioReading => _bioProcessor.lastValidBioData;
  
  /// Get the timestamp of the last valid bio reading.
  DateTime? get lastValidBioReadingTime => _bioProcessor.lastValidBioDataTimestamp;
  
  /// Get the last valid temperature reading.
  /// Returns null if no valid reading is available.
  TemperatureData? get lastValidTemperatureReading => _tempProcessor.lastValidData;
  
  /// Get the timestamp of the last valid temperature reading.
  DateTime? get lastValidTemperatureReadingTime => _tempProcessor.lastValidDataTimestamp;
  
  /// Check if bio reading is still fresh (within timeout).
  /// Useful for determining if last reading should be displayed.
  BioData? getFreshBioReading([Duration timeout = const Duration(seconds: 60)]) {
    return _bioProcessor.getFreshValidReading(timeout);
  }
  
  /// Check if temperature reading is still fresh (within timeout).
  /// Useful for determining if last reading should be displayed.
  TemperatureData? getFreshTemperatureReading([Duration timeout = const Duration(seconds: 60)]) {
    return _tempProcessor.getFreshValidReading(timeout);
  }

  void dispose() {
    _rawSub?.cancel();
    _bleConnectionSub?.cancel();
    _nativeConnectionSub?.cancel();
    _nativeHumanSub?.cancel();
    _nativeBpmSub?.cancel();
    _nativeSpo2Sub?.cancel();
    _bioSub?.cancel();
    _tempSub?.cancel();
    _statusAggregator.dispose();
    _bioProcessor.dispose();
    _tempProcessor.dispose();
    _connectionStateController.close();
    _displayStatusController.close();
    _telemetryController.close();
    _eventsController.close();
  }
}


