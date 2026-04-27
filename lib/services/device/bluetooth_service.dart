import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';



// Events that instruct the UI to show a dialog or request user input.
enum BluetoothUserActionType { enableBluetooth, requestPermissions }

class BluetoothUserAction {
  final BluetoothUserActionType type;
  const BluetoothUserAction(this.type);
}

// TODO: add more robust error reporting and expose status events if needed.
class BluetoothService {
  // Singleton instance
  static final BluetoothService _instance = BluetoothService._internal();
  
  factory BluetoothService() => _instance;
  
  BluetoothService._internal();

  // Toggle detailed BLE debug logs (set false to silence)
  static const bool BLE_DEBUG = false;

  // Events that require a UI interaction (dialogs). The UI should listen
  // to `userAction$` and show the appropriate prompt. After the user acts,
  // the UI should call `performEnableBluetooth()` or `performRequestPermissions()`
  // which will complete the service's pending operations.
  // TODO: consider richer event payloads in future (messages, action ids).
  final StreamController<BluetoothUserAction> _userActionController = StreamController.broadcast();
  Stream<BluetoothUserAction> get userAction$ => _userActionController.stream;

  Completer<bool>? _pendingEnableCompleter;
  


  // Broadcast controllers to allow multiple UI listeners.
  final StreamController<List<ScanResult>> _foundController = StreamController.broadcast();
  final StreamController<BluetoothDevice?> _connectedController = StreamController.broadcast();
  final StreamController<bool> _nativeConnectedController = StreamController.broadcast();
  final StreamController<bool> _nativeHumanDetectedController = StreamController.broadcast();
  final StreamController<int> _nativeBpmController = StreamController.broadcast();
  final StreamController<int> _nativeSpo2Controller = StreamController.broadcast();
  final StreamController<String> _incomingController = StreamController.broadcast();
  final StreamController<List<int>> _incomingRawController = StreamController.broadcast();

  Stream<List<ScanResult>> get foundDevices$ => _foundController.stream;
  Stream<BluetoothDevice?> get connectedDevice$ => _connectedController.stream;
  Stream<bool> get nativeConnected$ => _nativeConnectedController.stream;
  Stream<bool> get nativeHumanDetected$ => _nativeHumanDetectedController.stream;
  Stream<int> get nativeBpm$ => _nativeBpmController.stream;
  Stream<int> get nativeSpo2$ => _nativeSpo2Controller.stream;
  Stream<String> get incomingData$ => _incomingController.stream;
  Stream<List<int>> get incomingRaw$ => _incomingRawController.stream;
  


  // Debug information mapping (rssi/adv payload) for UI diagnostics.
  final Map<String, String> _debugInfo = {};
  Map<String, String> get debugInfo => _debugInfo;

  // Internal state
  final List<ScanResult> _found = [];
  Timer? _foundEmitTimer;
  bool _foundDirty = false;
  StreamSubscription? _scanSub;
  Timer? _scanStopTimer;
  DateTime? _lastScanStart;
  final Duration _scanDebounce = const Duration(seconds: 5);
  BluetoothDevice? _connected;
  // `_activeChar` was removed because characteristic handling uses subscriptions directly.
  StreamSubscription<List<int>>? _charSub;
  String? _savedId;
  bool _nativeEventsAttached = false;
  StreamSubscription? _nativeEventsSub;
  
  bool _nativeConnected = false;
  bool _nativeHumanDetected = false;
  int _nativeBpm = 0;
  int _nativeSpo2 = 0;

  bool get isNativeConnected => _nativeConnected;
  bool get isNativeHumanDetected => _nativeHumanDetected;
  int get nativeBpm => _nativeBpm;
  int get nativeSpo2 => _nativeSpo2;

  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  Completer<Map<String, dynamic>>? _pendingPermissionCompleter;

  String _getDeviceName(ScanResult r) {
    String name = '';
    try {
      final platformName = r.device.platformName;
      final advName = r.advertisementData.advName;
      if (platformName.isNotEmpty) {
        name = platformName;
      } else if (advName.isNotEmpty) {
        name = advName;
      }
    } catch (_) {
      try {
        final advName = r.advertisementData.advName;
        if (advName.isNotEmpty) name = advName;
      } catch (_) {}
    }
    return name;
  }

  bool _isPriorityDevice(ScanResult r) {
    return _getDeviceName(r) == 'M5-IMU-Sensor';
  }

  // Expose current permission snapshot for UI convenience.
  Map<String, bool> _permissionStatuses = {};
  Map<String, bool> get permissionStatuses => Map.unmodifiable(_permissionStatuses);


  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedId = prefs.getString('saved_device_id');
      // Detect native service and attach EventChannel early.
      bool nativeRunning = false;
      try {
        nativeRunning = await _platform.invokeMethod('isNativeServiceRunning') == true;
      } catch (_) {}
      try {
        _attachNativeEventStream();
      } catch (_) {}
      // Emit persisted native state immediately only if native service is not running
      // to avoid UI reset when native status will override it.
      if (!nativeRunning) {
        try {
          // Do NOT emit connected=true just because we have a saved ID.
          // This causes "ghost" connections where the UI thinks we are connected
          // but there is no actual connection.
          // instead, we only emit stored bytes if available for debug.
          final lastB64 = prefs.getString('last_bytes_b64');
          if (lastB64 != null) {
            try {
              final bytes = base64.decode(lastB64);
              if (bytes.isNotEmpty) {
                _incomingRawController.add(List<int>.from(bytes));
                _incomingController.add(_decode(bytes));
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
      // Ask for native status and wait for its reply so UI doesn't flip.
      try {
        final res = await _platform.invokeMethod('requestNativeStatus');
        if (res is Map) {
          final m = Map<String, dynamic>.from(res);
          _handleNativeStatusMap(m);
        }
      } catch (_) {}
      // Only attempt Flutter-side auto-reconnect if native service is NOT running.
      if (!nativeRunning && _savedId != null) {
        // try a background auto-reconnect without UI prompts
        _autoReconnect(_savedId!);
      }
      // NOTE: do not auto-start the native service here. The UI or connect
      // flows will start it deliberately to avoid scanning/running BLE when
      // the user hasn't requested it.
    } catch (_) {}
  }

  /// Re-attach the native event stream and request fresh status.
  /// Should be called when the app returns from background to recover
  /// the severed EventChannel bridge.
  Future<void> reattachNativeEventStream() async {
    _attachNativeEventStream();
    await requestNativeStatus();
  }

  void _attachNativeEventStream() {
    // If already attached, cancel and re-attach to ensure fresh connection
    // This fixes issues where the native side might have dropped the receiver but we still think we are attached.
    if (_nativeEventsAttached) {
       _nativeEventsSub?.cancel();
       _nativeEventsSub = null;
       _nativeEventsAttached = false;
    }

    try {
      final ev = EventChannel('sync_companion/ble_events');
      _nativeEventsSub = ev.receiveBroadcastStream().listen((dynamic event) {
        try {
          if (BLE_DEBUG) print('BLE: native event received type=${event.runtimeType}');
          if (event is List) {
            final bytes = List<int>.from(event.map((e) => e as int));
            if (BLE_DEBUG) print('BLE: received bytes len=${bytes.length}');
            _incomingRawController.add(bytes);
            final s = _decode(bytes);
            _incomingController.add(s);
          } else if (event is Map) {
            try {
              final m = Map<String, dynamic>.from(event);
              if (BLE_DEBUG) print('BLE: event map keys=${m.keys}');
              // Handle status events
              if (m.containsKey('status')) {
                _handleNativeStatusMap(m);
              }
              // Handle lastBytes events that come without status (live BLE_EVENT broadcasts)
              if (m.containsKey('lastBytes') && !m.containsKey('status')) {
                try {
                  final lb = m['lastBytes'];
                  if (lb is List) {
                    final bytes = List<int>.from(lb.map((e) => (e as int)));
                    if (bytes.isNotEmpty) {
                      if (BLE_DEBUG) print('BLE: live lastBytes len=${bytes.length}, rawListeners=${_incomingRawController.hasListener}');
                      _incomingRawController.add(bytes);
                      _incomingController.add(_decode(bytes));
                    }
                  }
                } catch (e) {
                  if (BLE_DEBUG) print('BLE: failed to handle live lastBytes: $e');
                }
              }
            } catch (e) {
              if (BLE_DEBUG) print('BLE: failed to handle map event: $e');
            }
          }
        } catch (_) {}
      }, onError: (e) {
        if (BLE_DEBUG) print('BLE: native event stream error: $e');
        _nativeEventsAttached = false;
        _nativeEventsSub?.cancel();
        _nativeEventsSub = null;
      }, onDone: () {
        if (BLE_DEBUG) print('BLE: native event stream done');
        _nativeEventsAttached = false;
        _nativeEventsSub?.cancel();
        _nativeEventsSub = null;
      });
      _nativeEventsAttached = true;
    } catch (e) {
      if (BLE_DEBUG) print('BLE: attachNativeEventStream failed: $e');
    }
  }

  void _handleNativeStatusMap(Map<String, dynamic> m) {
    try {
      final connected = m['status'] == true;
      final humanDetected = m['humanDetected'] == true;
      final bpm = m['bpm'] as int? ?? 0;
      final spo2 = m['spo2'] as int? ?? 0;
      
      if (BLE_DEBUG) print('BLE: native status map connected=$connected humanDetected=$humanDetected bpm=$bpm');
      // Update state
      _nativeConnected = connected;
      _nativeHumanDetected = humanDetected;
      _nativeBpm = bpm;
      _nativeSpo2 = spo2;
      
      // Emit canonical native states
      _nativeConnectedController.add(connected);
      _nativeHumanDetectedController.add(humanDetected);
      _nativeBpmController.add(bpm);
      _nativeSpo2Controller.add(spo2);
      if (!connected) {
        _connected = null;
        _connectedController.add(null);
      }
      // If native provided a device id, update saved id
      // CRITICAL FIX: Only update saved ID if we are actually connected.
      // If we are disconnecting (status=false), the native service might send
      // the ID of the device being disconnected. We should NOT overwrite our
      // current target device ID with the old one we just left.
      if (m.containsKey('deviceId') && connected) {
        try {
          final id = m['deviceId'] as String?;
          if (id != null) {
            _savedId = id;
            SharedPreferences.getInstance().then((prefs) => prefs.setString('saved_device_id', id));
          }
        } catch (_) {}
      }
      // If native provided lastBytes, replay once into incoming streams
      if (m.containsKey('lastBytes')) {
        try {
          final lb = m['lastBytes'];
          List<int> bytes = [];
          if (lb is List) {
            bytes = List<int>.from(lb.map((e) => (e as int)));
          }
          if (bytes.isNotEmpty) {
            if (BLE_DEBUG) print('BLE: replaying lastBytes len=${bytes.length}');
            _incomingRawController.add(bytes);
            _incomingController.add(_decode(bytes));
            // Optional: acknowledge native status receipt so native can cancel its short timeout
            try {
              if (m.containsKey('deviceId')) {
                final id = m['deviceId'] as String?;
                if (id != null) {
                  _platform.invokeMethod('nativeStatusAck', {'deviceId': id, 'timestamp': DateTime.now().millisecondsSinceEpoch});
                  if (BLE_DEBUG) print('BLE: sent nativeStatusAck for device=$id');
                }
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> startScan({Duration? timeout}) async {
    // Debounce and ensure adapter + permissions are OK. The service owns
    // the debounce logic so UI callers can simply call `startScan()`.
    final now = DateTime.now();
    if (_scanSub != null) return; // already scanning
    if (_lastScanStart != null && now.difference(_lastScanStart!) < _scanDebounce) return;
    _lastScanStart = now;

    final ok = await _ensureBluetoothOnBeforeScan();
    if (!ok) return;

    // Reset and start listening to scan results.
    _found.clear();
    _foundController.add(List<ScanResult>.from(_found));
    _scanSub?.cancel();
    try {
      await FlutterBluePlus.startScan();
    } catch (e) {
      // ignore start scan errors; notify UI via empty results
    }
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        // Skip devices without any visible name to reduce scan noise in UI
        String name = '';
        try {
          final platformName = r.device.platformName;
          final advName = r.advertisementData.advName;
          if (platformName.isNotEmpty) {
            name = platformName;
          } else if (advName.isNotEmpty) {
            name = advName;
          }
        } catch (_) {
          try {
            final advName = r.advertisementData.advName;
            if (advName.isNotEmpty) name = advName;
          } catch (_) {}
        }
        if (name.isEmpty) {
          if (BLE_DEBUG) print('BLE: skipping unnamed device ${r.device.remoteId.str}');
          continue;
        }
        final id = r.device.remoteId.str;
        try {
          _debugInfo[id] = 'rssi:${r.rssi} adv:${r.advertisementData}';
        } catch (_) {
          _debugInfo[id] = 'rssi:${r.rssi}';
        }
        if (!_found.any((e) => e.device.remoteId.str == id)) {
          _found.add(r);
        } else {
          final idx = _found.indexWhere((e) => e.device.remoteId.str == id);
          if (idx != -1) _found[idx] = r;
        }
        _foundDirty = true;
      }
      // batch emit to reduce UI jitter (coalesce frequent rssi updates)
      _foundEmitTimer ??= Timer(const Duration(milliseconds: 250), () {
        if (_foundDirty) {
          try {
            // Prioritize M5-IMU-Sensor device in scan results
            _found.sort((a, b) => _isPriorityDevice(a) ? -1 : _isPriorityDevice(b) ? 1 : 0);
            _foundController.add(List<ScanResult>.from(_found));
          } catch (_) {}
        }
        _foundDirty = false;
        _foundEmitTimer?.cancel();
        _foundEmitTimer = null;
      });
    }, onError: (e) {
      if (BLE_DEBUG) print('BLE: scanResults error: $e');
    });
    _scanStopTimer?.cancel();
    if (timeout != null) {
      _scanStopTimer = Timer(timeout, () async {
        await stopScan();
      });
    }
  }

  // Called by UI when the user agreed to enable Bluetooth. This performs the
  // platform request and unblocks any pending `startScan()` call.
  Future<bool> performEnableBluetooth() async {
    bool enabled = false;
    try {
      enabled = await _platform.invokeMethod('enableBluetooth') == true;
    } catch (_) {}
    _pendingEnableCompleter?.complete(enabled);
    _pendingEnableCompleter = null;
    return enabled;
  }

  // Called by UI when the user agreed to grant permissions. This triggers the
  // platform request and unblocks pending `startScan()` calls.
  Future<bool> performRequestPermissions() async {
    try {
      final map = await _requestPermissionsOnce();
      _permissionStatuses = map.map((k, v) => MapEntry(k.toString(), v == true));
      final ok = (_permissionStatuses['android.permission.BLUETOOTH_SCAN'] == true || _permissionStatuses['BLUETOOTH_SCAN'] == true) &&
          (_permissionStatuses['android.permission.BLUETOOTH_CONNECT'] == true || _permissionStatuses['BLUETOOTH_CONNECT'] == true);
      return ok;
    } catch (e) {
      if (BLE_DEBUG) print('BLE: performRequestPermissions failed: $e');
      return false;
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      final map = await _requestPermissionsOnce();
      _permissionStatuses = map.map((k, v) => MapEntry(k.toString(), v == true));
      return (_permissionStatuses['android.permission.BLUETOOTH_SCAN'] == true || _permissionStatuses['BLUETOOTH_SCAN'] == true) &&
          (_permissionStatuses['android.permission.BLUETOOTH_CONNECT'] == true || _permissionStatuses['BLUETOOTH_CONNECT'] == true);
    } catch (e) {
      if (BLE_DEBUG) print('BLE: _checkPermissions failed: $e');
      return false;
    }
  }

  // Ensure only one concurrent platform permission request is issued.
  Future<Map<String, dynamic>> _requestPermissionsOnce() async {
    if (_pendingPermissionCompleter != null) return _pendingPermissionCompleter!.future;
    _pendingPermissionCompleter = Completer<Map<String, dynamic>>();
    try {
      final res = await _platform.invokeMethod('requestPermissions');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        _pendingPermissionCompleter?.complete(map);
      } else {
        _pendingPermissionCompleter?.complete({});
      }
    } catch (e) {
      _pendingPermissionCompleter?.completeError(e);
    }
    final future = _pendingPermissionCompleter!.future;
    _pendingPermissionCompleter = null;
    return future;
  }

  Future<bool> _ensureBluetoothOnBeforeScan() async {
    try {
      final enabledNow = await isBluetoothEnabled();
      if (enabledNow) {
        // Just check permissions silently; MainActivity will handle prompts
        final permsOk = await _checkPermissions();
        return permsOk;
      }
      // If not enabled, ask UI to prompt user to enable then perform platform enable.
      _userActionController.add(const BluetoothUserAction(BluetoothUserActionType.enableBluetooth));
      _pendingEnableCompleter = Completer<bool>();
      final enabled = await _pendingEnableCompleter!.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (!enabled) return false;
      // after enabling, check permissions silently
      final permsOk = await _checkPermissions();
      return permsOk;
    } catch (e) {
      return false;
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
    _scanStopTimer?.cancel();
    _scanStopTimer = null;
  }

  Future<void> connect(BluetoothDevice device, {bool save = true}) async {
    try {
      // Always use native service to manage connections. Native service runs
      // in a foreground process and will survive app swipe kills.
      final did = device.remoteId.str;
      // Ensure we are listening for native events (attach before/after connect)
      try {
        _attachNativeEventStream();
      } catch (_) {}
      await _platform.invokeMethod('connect', {'id': did});
      // Ask native service to emit current status and reconcile when it replies
      try {
        final res = await _platform.invokeMethod('requestNativeStatus');
        if (res is Map) {
          final m = Map<String, dynamic>.from(res);
          _handleNativeStatusMap(m);
        }
      } catch (_) {}
      _connected = device;
      // Optimistically mark native-connected locally so UI updates immediately.
      _nativeConnectedController.add(true);
      if (save) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_device_id', did);
        _savedId = did;
      }
      _connectedController.add(_connected);
    } catch (e) {
      if (BLE_DEBUG) print('BLE: native connect failed: $e');
      _connected = null;
      _connectedController.add(null);
    }
  }

  /// Instruct native service to refresh its notification text. Useful after
  /// toggling the `notif_show_data` preference so the native foreground
  /// notification reflects the new setting immediately.
  Future<void> updateNativeNotification() async {
    try {
      await _platform.invokeMethod('updateNotification');
    } catch (_) {}
  }



  /// Forget any saved device id and request disconnect from native service.
  Future<void> forget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_device_id');
      _savedId = null;
    } catch (_) {}
    try {
      await _platform.invokeMethod('disconnect');
    } catch (_) {}
    // reflect disconnect immediately in UI
    _nativeConnectedController.add(false);
  }

  Future<void> disconnect() async {
    try {
      await _platform.invokeMethod('disconnect');
    } catch (_) {
      try {
        await _connected?.disconnect();
      } catch (_) {}
    }
    _charSub?.cancel();
    _charSub = null;
    _connected = null;
    _connectedController.add(null);
    // immediately reflect native disconnected state in the UI
    _nativeConnectedController.add(false);
  }

  Future<void> _autoReconnect(String id) async {
    while (_connected == null) {
      try {
        await startScan(timeout: const Duration(seconds: 6));
        await Future.delayed(const Duration(seconds: 4));
        ScanResult? match;
        for (final r in _found) {
            if (r.device.remoteId.str == id) {
            match = r;
            break;
          }
        }
        await stopScan();
        if (match != null) {
          await connect(match.device, save: false);
          break;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  String _decode(List<int> bytes) {
    try {
      if (bytes.isEmpty) return '';
      return utf8.decode(bytes);
    } catch (_) {
      return bytes.toString();
    }
  }

  /// Return the saved device id if any (used by UI to display which device
  /// the native service may be holding).
  String? getSavedDeviceId() => _savedId;

  // Optional platform utility used by UI if needed.
  Future<bool> isBluetoothEnabled() async {
    try {
      final enabled = await _platform.invokeMethod('isBluetoothEnabled');
      return enabled == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> requestPermissions() async {
    try {
      final res = await _platform.invokeMethod('requestPermissions');
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (_) {}
    return null;
  }

  /// Request native service to emit current status and telemetry data.
  /// This ensures the broadcast streams receive fresh data for new subscribers
  /// (e.g., minigames that need telemetry input).
  Future<void> requestNativeStatus() async {
    try {
      final res = await _platform.invokeMethod('requestNativeStatus');
      if (res is Map) {
        final m = Map<String, dynamic>.from(res);
        _handleNativeStatusMap(m);
      }
    } catch (_) {}
  }

  void dispose() {
    _foundController.close();
    _connectedController.close();
    _nativeConnectedController.close();
    _nativeHumanDetectedController.close();
    _nativeBpmController.close();
    _nativeSpo2Controller.close();
    _incomingController.close();
    _incomingRawController.close();
    _scanSub?.cancel();
    _charSub?.cancel();
    _nativeEventsSub?.cancel();
  }
}
