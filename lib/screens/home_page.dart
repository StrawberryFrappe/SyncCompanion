// ignore_for_file: unused_field, unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../foreground_handler.dart';
import '../services/bluetooth_service.dart' as bt_service;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final bt_service.BluetoothService _bt = bt_service.BluetoothService();
  BluetoothDevice? _connectedDevice;
  String _incoming = '';
  String _status = 'SEARCHING';
  bool _scanning = false;
  DateTime? _lastScanStart;
  final Duration _scanDebounce = const Duration(seconds: 5);
  final Duration _scanTimeout = const Duration(seconds: 30);
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  String _adapterState = 'unknown';
  Map<String, bool> _permissionStatuses = {};
  Map<String, String> _debugInfo = {};
  bool _bgServiceRunning = false;
  bool _showSyncNotification = true;

  StreamSubscription<BluetoothDevice?>? _connSub;
  StreamSubscription<String>? _incomingSub;
  StreamSubscription<bt_service.BluetoothUserAction>? _userActionSub;

  @override
  void initState() {
    super.initState();
    _init();
    _bt.init();
    _userActionSub = _bt.userAction$.listen((a) => _handleUserAction(a));
    _connSub = _bt.connectedDevice$.listen((d) {
      setState(() {
        _connectedDevice = d;
        _status = d != null ? 'LINKED' : 'SEARCHING';
      });
    });
    _incomingSub = _bt.incomingData$.listen((s) {
      setState(() => _incoming = s);
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _incomingSub?.cancel();
    _userActionSub?.cancel();
    _bt.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final enabled = await _platform.invokeMethod('isBluetoothEnabled');
      setState(() => _adapterState = (enabled == true) ? 'ON' : 'OFF');
    } on PlatformException catch (e) {
      print('isBluetoothEnabled failed: $e');
    }
    try {
      final running = await FlutterForegroundTask.isRunningService;
      setState(() => _bgServiceRunning = running);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final show = prefs.getBool('show_sync_notification');
    if (show != null) setState(() => _showSyncNotification = show);
    // preload debug info reference
    setState(() => _debugInfo = Map<String, String>.from(_bt.debugInfo));
  }

  Future<void> _handleUserAction(bt_service.BluetoothUserAction action) async {
    try {
      if (action.type == bt_service.BluetoothUserActionType.enableBluetooth) {
        final pressed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Bluetooth Disabled', style: TextStyle(fontSize: 12)),
            content: const Text('Bluetooth needs to be enabled to scan for devices.', style: TextStyle(fontSize: 10)),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('CANCEL', style: TextStyle(fontSize: 10))),
              TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('ENABLE BLUETOOTH', style: TextStyle(fontSize: 10))),
            ],
          ),
        );
        if (pressed == true) {
          final enabled = await _bt.performEnableBluetooth();
          setState(() => _adapterState = enabled ? 'ON' : 'OFF');
        }
      } else if (action.type == bt_service.BluetoothUserActionType.requestPermissions) {
        final pressed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Permissions required', style: TextStyle(fontSize: 12)),
            content: const Text('Bluetooth permissions are required. Please grant them in Settings or allow when prompted.', style: TextStyle(fontSize: 10)),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('CANCEL', style: TextStyle(fontSize: 10))),
              TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('REQUEST', style: TextStyle(fontSize: 10))),
            ],
          ),
        );
        if (pressed == true) {
          final ok = await _bt.performRequestPermissions();
          setState(() => _permissionStatuses = _bt.permissionStatuses);
          if (!ok) {
            await showDialog<void>(context: context, builder: (c) => AlertDialog(
              title: const Text('Permissions required', style: TextStyle(fontSize: 12)),
              content: const Text('Could not acquire required permissions. Please grant them in Android Settings.', style: TextStyle(fontSize: 10)),
              actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK', style: TextStyle(fontSize: 10)))],
            ));
          }
        }
      }
    } catch (e) {
      // ignore UI errors
    }
  }

  Future<void> _startBackgroundTask() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await _bt.performRequestPermissions();
    setState(() => _permissionStatuses = _bt.permissionStatuses);
    final scanOk = _permissionStatuses['android.permission.BLUETOOTH_SCAN'] == true || _permissionStatuses['BLUETOOTH_SCAN'] == true;
    final connectOk = _permissionStatuses['android.permission.BLUETOOTH_CONNECT'] == true || _permissionStatuses['BLUETOOTH_CONNECT'] == true;
    if (!scanOk || !connectOk) {
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Permissions required', style: TextStyle(fontSize: 12)),
        content: const Text('Bluetooth permissions are required to run in background. Please grant them in Settings.', style: TextStyle(fontSize: 10)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK', style: TextStyle(fontSize: 10))),
        ],
      ));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getBool('show_sync_notification');
    final showNotification = _showSyncNotification || (persisted == null ? true : persisted);
    String notifText;
    if (showNotification) {
      notifText = (_connectedDevice != null) ? 'The device is synced' : 'Running in background';
    } else {
      notifText = ' ';
    }

    try {
      await FlutterForegroundTask.startService(
        serviceId: 1,
        notificationTitle: 'Sync Companion',
        notificationText: notifText,
        callback: startCallback,
      );
      setState(() => _bgServiceRunning = true);
    } catch (e) {
      print('startBackgroundTask failed: $e');
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Background service failed', style: TextStyle(fontSize: 12)),
        content: const Text('Could not start the foreground background service. Please ensure the app has the required permissions (location/foreground service) in Android settings.', style: TextStyle(fontSize: 10)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK', style: TextStyle(fontSize: 10))),
        ],
      ));
    }
  }

  Future<void> _stopBackgroundTask() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    // Ensure required runtime permissions are granted first. The service
    // manages the actual permission request; UI simply invokes it and
    // updates its view of statuses.
    await _bt.performRequestPermissions();
    setState(() => _permissionStatuses = _bt.permissionStatuses);
  }

  // Permission and adapter flows are handled by `BluetoothService` now.

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      await _bt.startScan(timeout: _scanTimeout);
    } catch (e) {
      print('startScan error: $e');
    }
  }

  Future<void> _stopScan() async {
    try {
      await _bt.stopScan();
    } catch (_) {}
    setState(() => _scanning = false);
  }

  Future<void> _connectTo(BluetoothDevice device, {bool save = true}) async {
    try {
      setState(() => _status = 'CONNECTING');
      await _bt.connect(device, save: save);
    } catch (e) {
      setState(() => _status = 'SEARCHING');
    }
  }

  Future<void> _forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_device_id');
    try {
      await _bt.disconnect();
    } catch (_) {}
    setState(() {
      _incoming = '';
      _status = 'SEARCHING';
      _connectedDevice = null;
    });
  }

  void _openScanner() async {
    await _startScan();
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adapter: $_adapterState', style: const TextStyle(fontSize: 8)),
                    const SizedBox(height: 4),
                    Text('Perms: ${_permissionStatuses.entries.map((e) => '${e.key.split('.').last}:${e.value?"Y":"N"}').join(', ')}', style: const TextStyle(fontSize: 8)),
                    const SizedBox(height: 6),
                    if (_connectedDevice != null)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
                        child: SingleChildScrollView(
                          child: Text(
                            '${(_connectedDevice!.platformName.isNotEmpty ? _connectedDevice!.platformName : _connectedDevice!.remoteId.str)}\n${_incoming.isEmpty ? '—' : _incoming}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: _bt.foundDevices$,
                  builder: (ctx, snap) {
                    final found = snap.data ?? const [];
                    return ListView.separated(
                      itemCount: found.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.black, thickness: 2),
                      itemBuilder: (ctx2, i) {
                        final r = found[i];
                        final idStr = r.device.remoteId.str;
                        final name = (r.device.platformName.isNotEmpty ? r.device.platformName : idStr);
                        return ListTile(
                          title: Text(name, style: const TextStyle(fontSize: 10)),
                          subtitle: Text('$idStr\n${_bt.debugInfo[idStr] ?? ''}', style: const TextStyle(fontSize: 8)),
                          onTap: () async {
                            await _stopScan();
                            Navigator.of(context).pop();
                            await _connectTo(r.device, save: true);
                          },
                        );
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
    await _stopScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SYNC COMPANION', style: const TextStyle(fontSize: 14, fontFamily: 'Monocraft')),
        centerTitle: true,
        toolbarHeight: 56,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _connectedDevice != null ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(width: 2, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_connectedDevice != null ? 'CONNECTED' : _status, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                height: 80,
                child: Image.asset('placeholder.png', fit: BoxFit.contain),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
