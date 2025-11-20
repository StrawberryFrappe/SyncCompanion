import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const SyncCompanionApp());

class SyncCompanionApp extends StatelessWidget {
  const SyncCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();
    return MaterialApp(
      title: 'Sync Companion',
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.pressStart2pTextTheme(
          base.textTheme.apply(bodyColor: Colors.black),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// Compatibility shim for older tests that expect `MyApp`.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const SyncCompanionApp();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // use FlutterBluePlus static APIs directly
  final List<ScanResult> _found = [];
  StreamSubscription? _scanSub;
  BluetoothDevice? _connectedDevice;
  // characteristic placeholder removed; we handle subscriptions directly
  Timer? _readTimer;
  String _incoming = '';
  String _status = 'SEARCHING';
  String? _savedId;
  bool _scanning = false;
  // platform channel to ask Android to enable Bluetooth and request permissions
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  String _adapterState = 'unknown';
  Map<String, bool> _permissionStatuses = {};
  final Map<String, String> _debugInfo = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _readTimer?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  Future<void> _init() async {
    // listen to adapter state so UI and scan logic can react
    // query platform for current adapter state
    try {
      final enabled = await _platform.invokeMethod('isBluetoothEnabled');
      setState(() => _adapterState = (enabled == true) ? 'ON' : 'OFF');
    } on PlatformException catch (e) {
      print('isBluetoothEnabled failed: $e');
    }
    await _requestPermissions();
    final prefs = await SharedPreferences.getInstance();
    _savedId = prefs.getString('saved_device_id');
    if (_savedId != null) {
      _autoReconnect(_savedId!);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final res = await _platform.invokeMethod('requestPermissions');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        setState(() {
          _permissionStatuses = map.map((k, v) => MapEntry(k.toString(), v == true));
        });
      }
    } on PlatformException catch (e) {
      print('permission request failed: $e');
    }
  }

  Future<void> _autoReconnect(String id) async {
    // keep trying until connected
    while (mounted && _connectedDevice == null) {
      try {
        setState(() => _status = 'SEARCHING');
        FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
        final results = await FlutterBluePlus.scanResults.first;
        ScanResult? match;
        for (final r in results) {
          if (r.device.id.id == id) {
            match = r;
            break;
          }
        }
        if (match != null) {
          await FlutterBluePlus.stopScan();
          await _connectTo(match.device, save: false);
          break;
        }
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _connectTo(BluetoothDevice device, {bool save = true}) async {
    try {
      setState(() => _status = 'CONNECTING');
      await device.connect(autoConnect: false).timeout(const Duration(seconds: 8));
      _connectedDevice = device;
      if (save) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_device_id', device.id.id);
        _savedId = device.id.id;
      }
      setState(() => _status = 'LINKED');
      final services = await device.discoverServices();
      // find first characteristic with notify or write; prefer notify
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
      if (chosen != null) {
        if (chosen.properties.notify) {
          await chosen.setNotifyValue(true);
          chosen.lastValueStream.listen((b) {
            final s = _decode(b);
            setState(() => _incoming = s);
          });
        } else if (chosen.properties.read) {
          _readTimer?.cancel();
          final c = chosen;
          _readTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
            try {
              final b = await c.read();
              final s = _decode(b);
              setState(() => _incoming = s);
            } catch (_) {}
          });
        }
      }
    } catch (e) {
      setState(() => _status = 'SEARCHING');
      try {
        await device.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }
  }

  String _decode(List<int> bytes) {
    try {
      if (bytes.isEmpty) return '';
      final s = utf8.decode(bytes);
      return s;
    } catch (_) {
      return bytes.toString();
    }
  }

  Future<void> _startScan() async {
    // Ensure adapter is ON before attempting to scan
    final ok = await _ensureBluetoothOnBeforeScan();
    if (!ok) {
      setState(() {
        _status = 'BLUETOOTH_OFF';
      });
      return;
    }

    _found.clear();
    setState(() {
      _scanning = true;
    });
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.id.id;
        // store debug info for diagnostics
        try {
          _debugInfo[id] = 'rssi:${r.rssi} adv:${r.advertisementData}';
        } catch (_) {
          _debugInfo[id] = 'rssi:${r.rssi}';
        }
        if (!_found.any((e) => e.device.id.id == id)) {
          setState(() => _found.add(r));
        } else {
          // update to refresh debug data
          setState(() {});
        }
      }
      // diagnostic log of raw results each time
      print('scanResults: ${results.map((r) => r.device.id.id).toList()}');
    });
    // ensure scanning flag is cleared after timeout
    Future.delayed(const Duration(seconds: 6), () async {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await _scanSub?.cancel();
      if (mounted) setState(() => _scanning = false);
    });
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    setState(() => _scanning = false);
  }

  Future<bool> _ensureBluetoothOnBeforeScan() async {
    try {
      final enabledNow = await _platform.invokeMethod('isBluetoothEnabled');
      if (enabledNow == true) return true;
      // show dialog asking user to enable
      final pressed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Bluetooth Disabled', style: TextStyle(fontSize: 12)),
          content: const Text('Bluetooth needs to be enabled to scan for devices.', style: TextStyle(fontSize: 10)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('CANCEL', style: TextStyle(fontSize: 10)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(c).pop(true);
              },
              child: const Text('ENABLE BLUETOOTH', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      );
      if (pressed != true) return false;
      // ask platform to present system enable intent
      bool enabled = false;
      try {
        enabled = await _platform.invokeMethod('enableBluetooth') == true;
      } on PlatformException catch (e) {
        print('enable intent failed: $e');
      }
      // poll for adapter state briefly via platform
      for (int i = 0; i < 10; i++) {
        final now = await _platform.invokeMethod('isBluetoothEnabled');
        if (now == true) return true;
        await Future.delayed(const Duration(milliseconds: 300));
      }
      return enabled;
    } catch (e) {
      print('ensureBluetoothOnBeforeScan error: $e');
      return false;
    }
  }

  Future<void> _forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_device_id');
    _savedId = null;
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    // characteristic cleared
    _readTimer?.cancel();
    setState(() {
      _incoming = '';
      _status = 'SEARCHING';
    });
  }

  void _openScanner() async {
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SCAN', style: TextStyle(fontSize: 10)),
                  IconButton(
                    icon: Icon(_scanning ? Icons.stop : Icons.refresh, color: Colors.black),
                    onPressed: () async {
                      if (_scanning) {
                        await _stopScan();
                      } else {
                        _found.clear();
                        await _startScan();
                      }
                    },
                  )
                ],
              ),
              const Divider(color: Colors.black, thickness: 2),
              Expanded(
                child: ListView.separated(
                  itemCount: _found.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.black, thickness: 2),
                  itemBuilder: (ctx, i) {
                    final r = _found[i];
                    final name = r.device.name.isNotEmpty ? r.device.name : r.device.id.id;
                    return ListTile(
                      title: Text(name, style: const TextStyle(fontSize: 10)),
                      subtitle: Text('${r.device.id.id}\n${_debugInfo[r.device.id.id] ?? ''}', style: const TextStyle(fontSize: 8)),
                      onTap: () async {
                        await _stopScan();
                        Navigator.of(context).pop();
                        await _connectTo(r.device, save: true);
                      },
                    );
                  },
                ),
              ),
              if (_connectedDevice != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(width: 2, color: Colors.black)),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _forget();
                  },
                  child: const Text('Disconnect & Forget', style: TextStyle(fontSize: 10)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SYNC COMPANION'),
        centerTitle: true,
        toolbarHeight: 56,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_status, style: const TextStyle(fontSize: 8)),
                  Text(_savedId ?? 'No saved device', style: const TextStyle(fontSize: 8)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Diagnostics: adapter state and permission list
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adapter: $_adapterState', style: const TextStyle(fontSize: 8)),
                  const SizedBox(height: 4),
                  Text('Perms: ${_permissionStatuses.entries.map((e) => '${e.key.split('.').last}:${e.value?"Y":"N"}').join(', ')}', style: const TextStyle(fontSize: 8)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 160,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
              child: SingleChildScrollView(
                child: Text(_incoming.isEmpty ? '—' : _incoming, style: const TextStyle(fontSize: 10)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(width: 2, color: Colors.black)),
                    onPressed: _openScanner,
                    child: const Text('SETTINGS', style: TextStyle(fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 8),
                if (_connectedDevice != null)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(width: 2, color: Colors.black)),
                      onPressed: _forget,
                      child: const Text('DISCONNECT', style: TextStyle(fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
