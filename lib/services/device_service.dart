import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;
import 'package:shared_preferences/shared_preferences.dart';

import 'bluetooth_service.dart';
export 'bluetooth_service.dart' show BluetoothUserAction, BluetoothUserActionType;
import 'telemetry_data.dart';

/// High-level device state.
enum DeviceConnectionState {
  disconnected,
  searching,
  connecting,
  connected,
}

abstract class DeviceEvent {}

class ShakeEvent extends DeviceEvent {}
class TapEvent extends DeviceEvent {}

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

  final StreamController<TelemetryData> _telemetryController =
      StreamController.broadcast();
  Stream<TelemetryData> get telemetry$ => _telemetryController.stream;

  final StreamController<DeviceEvent> _eventsController =
      StreamController.broadcast();
  Stream<DeviceEvent> get events$ => _eventsController.stream;

  DeviceConnectionState _currentState = DeviceConnectionState.disconnected;
  DeviceConnectionState get currentState => _currentState;

  StreamSubscription? _rawSub;
  StreamSubscription? _bleConnectionSub;
  StreamSubscription? _nativeConnectionSub;

  // Cloud Relay Stub
  // In the future, this could be its own service or a more complex logic.
  // For now, we just want to ensure we have a place to hook into the data stream.
  void Function(TelemetryData)? _cloudRelayCallback;

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
        _cloudRelayCallback?.call(data);
      }
    });
  }

  void _updateState(DeviceConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(newState);
    }
  }

  // --- High Level Logic ---

  void _checkForHighLevelEvents(TelemetryData data) {
    // Simple examples of event derivation
    if (data.magnitude > 2.5) {
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

  // Set Cloud Relay Callback
  void setCloudRelayCallback(void Function(TelemetryData) callback) {
    _cloudRelayCallback = callback;
  }

  void dispose() {
    _rawSub?.cancel();
    _bleConnectionSub?.cancel();
    _nativeConnectionSub?.cancel();
    _connectionStateController.close();
    _telemetryController.close();
    _eventsController.close();
  }
}
