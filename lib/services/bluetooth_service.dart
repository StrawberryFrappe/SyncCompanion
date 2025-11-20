import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// TODO: add more robust error reporting and expose status events if needed.
class BluetoothService {
  BluetoothService();

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
  BluetoothDevice? _connected;
  // `_activeChar` was removed because characteristic handling uses subscriptions directly.
  StreamSubscription<List<int>>? _charSub;
  String? _savedId;

  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');

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
