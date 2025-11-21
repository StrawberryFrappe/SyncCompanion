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
  BluetoothService();

  // Toggle detailed BLE debug logs (set false to silence)
  static const bool BLE_DEBUG = true;

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
  final StreamController<String> _incomingController = StreamController.broadcast();
  final StreamController<List<int>> _incomingRawController = StreamController.broadcast();

  Stream<List<ScanResult>> get foundDevices$ => _foundController.stream;
  Stream<BluetoothDevice?> get connectedDevice$ => _connectedController.stream;
  Stream<bool> get nativeConnected$ => _nativeConnectedController.stream;
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

  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  Completer<Map<String, dynamic>>? _pendingPermissionCompleter;

  // Expose current permission snapshot for UI convenience.
  Map<String, bool> _permissionStatuses = {};
  Map<String, bool> get permissionStatuses => Map.unmodifiable(_permissionStatuses);


  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedId = prefs.getString('saved_device_id');
      // If a native Android BLE service is available, subscribe to its events
      bool nativeRunning = false;
      try {
        nativeRunning = await _platform.invokeMethod('isNativeServiceRunning') == true;
        if (nativeRunning) {
          _attachNativeEventStream();
          // Ask native service to emit current status immediately
          try {
            await _platform.invokeMethod('requestNativeStatus');
          } catch (_) {}
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

  void _attachNativeEventStream() {
    try {
      final ev = EventChannel('sync_companion/ble_events');
      ev.receiveBroadcastStream().listen((dynamic event) {
        try {
              if (event is List) {
            final bytes = List<int>.from(event.map((e) => e as int));
            _incomingRawController.add(bytes);
            final s = _decode(bytes);
            _incomingController.add(s);
          } else if (event is Map) {
            // status event from native service
            try {
              final m = Map<String, dynamic>.from(event);
              if (m.containsKey('status')) {
                final connected = m['status'] == true;
                    // emit native-connected boolean so UI can react without
                    // needing a concrete `BluetoothDevice` object.
                    _nativeConnectedController.add(connected);
                    if (!connected) {
                      _connected = null;
                      _connectedController.add(null);
                    }
              }
            } catch (_) {}
          }
        } catch (_) {}
      }, onError: (e) {
        if (BLE_DEBUG) print('BLE: native event stream error: $e');
      });
    } catch (e) {
      if (BLE_DEBUG) print('BLE: attachNativeEventStream failed: $e');
    }
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
          final advName = r.advertisementData.localName;
          if (platformName.isNotEmpty) {
            name = platformName;
          } else if (advName.isNotEmpty) {
            name = advName;
          }
        } catch (_) {
          try {
            final advName = r.advertisementData.localName;
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
      await _platform.invokeMethod('connect', {'id': did});
      _connected = device;
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

  void dispose() {
    _foundController.close();
    _connectedController.close();
    _nativeConnectedController.close();
    _incomingController.close();
    _incomingRawController.close();
    _scanSub?.cancel();
    _charSub?.cancel();
  }
}
