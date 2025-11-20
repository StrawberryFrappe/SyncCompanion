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

  // Events that require a UI interaction (dialogs). The UI should listen
  // to `userAction$` and show the appropriate prompt. After the user acts,
  // the UI should call `performEnableBluetooth()` or `performRequestPermissions()`
  // which will complete the service's pending operations.
  // TODO: consider richer event payloads in future (messages, action ids).
  final StreamController<BluetoothUserAction> _userActionController = StreamController.broadcast();
  Stream<BluetoothUserAction> get userAction$ => _userActionController.stream;

  Completer<bool>? _pendingEnableCompleter;
  Completer<bool>? _pendingPermissionCompleter;


  // Broadcast controllers to allow multiple UI listeners.
  final StreamController<List<ScanResult>> _foundController = StreamController.broadcast();
  final StreamController<BluetoothDevice?> _connectedController = StreamController.broadcast();
  final StreamController<String> _incomingController = StreamController.broadcast();

  Stream<List<ScanResult>> get foundDevices$ => _foundController.stream;
  Stream<BluetoothDevice?> get connectedDevice$ => _connectedController.stream;
  Stream<String> get incomingData$ => _incomingController.stream;

  // Debug information mapping (rssi/adv payload) for UI diagnostics.
  final Map<String, String> _debugInfo = {};
  Map<String, String> get debugInfo => _debugInfo;

  // Internal state
  final List<ScanResult> _found = [];
  StreamSubscription? _scanSub;
  Timer? _scanStopTimer;
  DateTime? _lastScanStart;
  final Duration _scanDebounce = const Duration(seconds: 5);
  BluetoothDevice? _connected;
  // `_activeChar` was removed because characteristic handling uses subscriptions directly.
  StreamSubscription<List<int>>? _charSub;
  String? _savedId;

  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');

  // Expose current permission snapshot for UI convenience.
  Map<String, bool> _permissionStatuses = {};
  Map<String, bool> get permissionStatuses => Map.unmodifiable(_permissionStatuses);


  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedId = prefs.getString('saved_device_id');
      if (_savedId != null) {
        // try a background auto-reconnect without UI prompts
        _autoReconnect(_savedId!);
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
        final id = r.device.remoteId.str;
        try {
          _debugInfo[id] = 'rssi:${r.rssi} adv:${r.advertisementData}';
        } catch (_) {
          _debugInfo[id] = 'rssi:${r.rssi}';
        }
        if (!_found.any((e) => e.device.remoteId.str == id)) {
          _found.add(r);
          _foundController.add(List<ScanResult>.from(_found));
        } else {
          // update existing entry (e.g., rssi)
          final idx = _found.indexWhere((e) => e.device.remoteId.str == id);
          if (idx != -1) {
            _found[idx] = r;
            _foundController.add(List<ScanResult>.from(_found));
          }
        }
      }
    }, onError: (e) {
      // ignore for now
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
    bool ok = false;
    try {
      final res = await _platform.invokeMethod('requestPermissions');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        _permissionStatuses = map.map((k, v) => MapEntry(k.toString(), v == true));
        ok = (_permissionStatuses['android.permission.BLUETOOTH_SCAN'] == true || _permissionStatuses['BLUETOOTH_SCAN'] == true) &&
            (_permissionStatuses['android.permission.BLUETOOTH_CONNECT'] == true || _permissionStatuses['BLUETOOTH_CONNECT'] == true);
      }
    } catch (_) {}
    _pendingPermissionCompleter?.complete(ok);
    _pendingPermissionCompleter = null;
    return ok;
  }

  Future<bool> _checkPermissions() async {
    try {
      final res = await _platform.invokeMethod('requestPermissions');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        _permissionStatuses = map.map((k, v) => MapEntry(k.toString(), v == true));
        return (_permissionStatuses['android.permission.BLUETOOTH_SCAN'] == true || _permissionStatuses['BLUETOOTH_SCAN'] == true) &&
            (_permissionStatuses['android.permission.BLUETOOTH_CONNECT'] == true || _permissionStatuses['BLUETOOTH_CONNECT'] == true);
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _ensureBluetoothOnBeforeScan() async {
    try {
      final enabledNow = await isBluetoothEnabled();
      if (enabledNow) {
        final permsOk = await _checkPermissions();
        if (permsOk) return true;
        // request permissions via UI
        _userActionController.add(const BluetoothUserAction(BluetoothUserActionType.requestPermissions));
        _pendingPermissionCompleter = Completer<bool>();
        final granted = await _pendingPermissionCompleter!.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
        return granted;
      }
      // If not enabled, ask UI to prompt user to enable then perform platform enable.
      _userActionController.add(const BluetoothUserAction(BluetoothUserActionType.enableBluetooth));
      _pendingEnableCompleter = Completer<bool>();
      final enabled = await _pendingEnableCompleter!.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (!enabled) return false;
      // after enabling, check permissions
      final permsOk = await _checkPermissions();
      if (permsOk) return true;
      _userActionController.add(const BluetoothUserAction(BluetoothUserActionType.requestPermissions));
      _pendingPermissionCompleter = Completer<bool>();
      final granted = await _pendingPermissionCompleter!.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
      return granted;
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
      _connectedController.add(null);
      await device.connect(autoConnect: false).timeout(const Duration(seconds: 8));
      _connected = device;
      if (save) {
        final prefs = await SharedPreferences.getInstance();
        final did = device.remoteId.str;
        await prefs.setString('saved_device_id', did);
        _savedId = did;
      }
      _connectedController.add(_connected);

      final services = await device.discoverServices();
      BluetoothCharacteristic? chosen;
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.notify) {
            chosen = c;
            break;
          }
          if (chosen == null && (c.properties.write || c.properties.read)) {
            chosen = c;
          }
        }
        if (chosen != null) break;
      }
      _charSub?.cancel();
      if (chosen != null) {
        if (chosen.properties.notify) {
          await chosen.setNotifyValue(true);
          _charSub = chosen.lastValueStream.listen((b) {
            final s = _decode(b);
            _incomingController.add(s);
          });
        } else if (chosen.properties.read) {
          // fallback: do periodic reads
          Timer.periodic(const Duration(seconds: 1), (t) async {
            try {
              final b = await chosen!.read();
              final s = _decode(b);
              _incomingController.add(s);
            } catch (_) {}
          });
        }
      }
    } catch (e) {
      try {
        await device.disconnect();
      } catch (_) {}
      _connected = null;
      _connectedController.add(null);
    }
  }

  Future<void> disconnect() async {
    try {
      await _connected?.disconnect();
    } catch (_) {}
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
    _incomingController.close();
    _scanSub?.cancel();
    _charSub?.cancel();
  }
}
