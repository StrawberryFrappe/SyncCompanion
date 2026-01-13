import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;

import 'bluetooth_service.dart';
export 'bluetooth_service.dart' show BluetoothUserAction, BluetoothUserActionType;


/// High-level device state.
enum DeviceConnectionState {
  disconnected,
  searching,
  connecting,
  connected,
}

/// UI-facing display status.
enum DeviceDisplayStatus {
  synced,    // Connected
  waiting,   // Disconnected but has saved ID
  searching, // Disconnected and no saved ID
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
  
  DeviceDisplayStatus get currentDisplayStatus {
    if (_currentState == DeviceConnectionState.connected) {
      return DeviceDisplayStatus.synced;
    }
    // If not connected, check if we are "waiting" (saved ID exists) or "searching"
    final hasSaved = _bluetooth.getSavedDeviceId() != null;
    return hasSaved ? DeviceDisplayStatus.waiting : DeviceDisplayStatus.searching;
  }

  StreamSubscription? _rawSub;
  StreamSubscription? _bleConnectionSub;
  StreamSubscription? _nativeConnectionSub;

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
        _telemetryController.add(data);
        _checkForHighLevelEvents(data);
      }
    });
    
    // Initial emission
    _displayStatusController.add(currentDisplayStatus);
  }

  void _updateState(DeviceConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(newState);
      // Also update display status
      _displayStatusController.add(currentDisplayStatus);
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
  Future<void> setNotifShowData(bool value) => _bluetooth.setNotifShowData(value);

  void dispose() {
    _rawSub?.cancel();
    _bleConnectionSub?.cancel();
    _nativeConnectionSub?.cancel();
    _connectionStateController.close();
    _telemetryController.close();
    _eventsController.close();
  }
}

/// Decoded IMU telemetry data from the M5-IMU-Sensor device.
/// 
/// The device sends 12 bytes: 6 × int16 little-endian values.
/// - Accelerometer (ax, ay, az): raw value ÷ 100 = g
/// - Gyroscope (gx, gy, gz): raw value ÷ 10 = deg/s
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

  const TelemetryData({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  /// Magnitude of the acceleration vector.
  /// Useful for motion detection (e.g., jump threshold in games).
  /// At rest, this should be ~1.0g (gravity).
  double get magnitude => sqrt(ax * ax + ay * ay + az * az);

  /// Factory to decode 12-byte IMU payload.
  /// Returns null if bytes are invalid.
  static TelemetryData? fromBytes(List<int> bytes) {
    if (bytes.length != 12) return null;
    
    try {
      final data = Uint8List.fromList(bytes);
      final byteData = ByteData.sublistView(data);
      
      // Read 6 × int16 little-endian
      final rawAx = byteData.getInt16(0, Endian.little);
      final rawAy = byteData.getInt16(2, Endian.little);
      final rawAz = byteData.getInt16(4, Endian.little);
      final rawGx = byteData.getInt16(6, Endian.little);
      final rawGy = byteData.getInt16(8, Endian.little);
      final rawGz = byteData.getInt16(10, Endian.little);
      
      return TelemetryData(
        ax: rawAx / 100.0,
        ay: rawAy / 100.0,
        az: rawAz / 100.0,
        gx: rawGx / 10.0,
        gy: rawGy / 10.0,
        gz: rawGz / 10.0,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 
      'A:(${ax.toStringAsFixed(2)}, ${ay.toStringAsFixed(2)}, ${az.toStringAsFixed(2)}) '
      'G:(${gx.toStringAsFixed(1)}, ${gy.toStringAsFixed(1)}, ${gz.toStringAsFixed(1)})';
}

