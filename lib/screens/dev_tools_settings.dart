// ignore_for_file: unused_field, unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_page.dart';
import '../services/bluetooth_service.dart' as bt_service;
import '../services/foreground_notification.dart';

/// DevToolsSettings - Contains all Bluetooth pairing, telemetry, and diagnostic
/// functionality. This was previously the main content of HomePage but is now
/// encapsulated into a modal dialog accessed via the cog button.
class DevToolsSettings extends StatefulWidget {
  const DevToolsSettings({super.key});

  @override
  State<DevToolsSettings> createState() => _DevToolsSettingsState();
}

class _DevToolsSettingsState extends State<DevToolsSettings> {
  final bt_service.BluetoothService _bt = bt_service.BluetoothService();
  BluetoothDevice? _connectedDevice;
  String _incoming = '';
  String _status = 'SEARCHING';
  bool _scanning = false;
  DateTime? _lastScanStart;
  final Duration _scanDebounce = const Duration(seconds: 5);
  final Duration _scanTimeout = const Duration(seconds: 7);
  
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  String _adapterState = 'unknown';
  Map<String, bool> _permissionStatuses = {};
  Map<String, String> _debugInfo = {};
  bool _bgServiceRunning = false;
  ForegroundNotificationUpdater? _notifUpdater;

  StreamSubscription<BluetoothDevice?>? _connSub;
  StreamSubscription<String>? _incomingSub;
  StreamSubscription<bt_service.BluetoothUserAction>? _userActionSub;

  bool _isConnected = false;
  bool _nativeStatusReceived = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _init();
    _bt.init();
    _loadPersisted();
    _userActionSub = _bt.userAction$.listen((a) => _handleUserAction(a));
    _connSub = _bt.connectedDevice$.listen((d) {
      setState(() {
        _connectedDevice = d;
        if (d != null) {
          _isConnected = true;
          _deviceId = d.remoteId.str;
          _status = 'LINKED';
        } else {
          _isConnected = false;
          _deviceId = null;
          _status = 'SEARCHING';
        }
      });
      // If a device became connected, ensure background service is running
      // so the notification updater can reflect incoming packets.
      if (d != null) {
        // Fire-and-forget; this will request permissions if needed.
        _startBackgroundTask();
      }
    });
    _bt.nativeConnected$.listen((connected) {
      _nativeStatusReceived = true;
      setState(() {
        _isConnected = connected;
        if (!connected) {
          _status = 'SEARCHING';
        }
      });
      if (connected && _deviceId == null) {
        // If connected but no device, perhaps load from prefs
        _loadPersistedDeviceId();
      }
    });
    _incomingSub = _bt.incomingData$.listen((s) {
      setState(() => _incoming = s);
    });
  }

  @override
  void dispose() {
    _notifUpdater?.stop();
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
      final running = await _platform.invokeMethod('isNativeServiceRunning');
      setState(() => _bgServiceRunning = (running == true));
    } catch (_) {}
    // preload debug info reference
    setState(() => _debugInfo = Map<String, String>.from(_bt.debugInfo));
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('saved_device_id');
    if (id != null) {
      setState(() {
        _isConnected = true;
        _deviceId = id;
        _status = 'LINKED';
      });
    }
  }

  Future<void> _loadPersistedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('saved_device_id');
    if (id != null) {
      setState(() => _deviceId = id);
    }
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
    // Ensure permissions first, then start the native BLE foreground service.
    await _bt.performRequestPermissions();
    setState(() => _permissionStatuses = _bt.permissionStatuses);
    final scanOk = _permissionStatuses['android.permission.BLUETOOTH_SCAN'] == true || _permissionStatuses['BLUETOOTH_SCAN'] == true;
    final connectOk = _permissionStatuses['android.permission.BLUETOOTH_CONNECT'] == true || _permissionStatuses['BLUETOOTH_CONNECT'] == true;
    if (!scanOk || !connectOk) {
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Permissions required', style: TextStyle(fontSize: 12)),
        content: const Text('Bluetooth permissions are required to run the native BLE service. Please grant them in Settings.', style: TextStyle(fontSize: 10)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK', style: TextStyle(fontSize: 10))),
        ],
      ));
      return;
    }

    try {
      await _platform.invokeMethod('startNativeService');
      setState(() => _bgServiceRunning = true);
    } catch (e) {
      print('startNativeService failed: $e');
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Native service failed', style: TextStyle(fontSize: 12)),
        content: const Text('Could not start the native BLE foreground service. Please ensure the app has the required permissions.', style: TextStyle(fontSize: 10)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK', style: TextStyle(fontSize: 10))),
        ],
      ));
    }
  }

  Future<void> _stopBackgroundTask() async {
    try {
      await _platform.invokeMethod('stopNativeService');
    } catch (_) {}
    _notifUpdater?.stop();
    _notifUpdater = null;
    setState(() => _bgServiceRunning = false);
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
      _isConnected = false;
      _deviceId = null;
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
                            '${(_connectedDevice!.platformName.isNotEmpty ? _connectedDevice!.platformName : _connectedDevice!.remoteId.str)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    if (_connectedDevice == null && _deviceId != null)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
                        child: Text(
                          'Persisted: $_deviceId',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _connectedDevice != null
                    ? ConnectedTerminal(bt: _bt, maxLines: 200)
                    : StreamBuilder<List<ScanResult>>(
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
                              // Simplified row: show name and two small numbers (RSSI and short id)
                              final shortId = idStr.length > 6 ? idStr.substring(idStr.length - 6) : idStr;
                              return ListTile(
                                title: Text(name, style: const TextStyle(fontSize: 12)),
                                subtitle: Text('RSSI: ${r.rssi} dBm', style: const TextStyle(fontSize: 10)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(border: Border.all(width: 1, color: Colors.black), borderRadius: BorderRadius.circular(4)),
                                  child: Text(shortId, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                                ),
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(width: 2, color: Colors.black),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(width: 2, color: Colors.black)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'DEV TOOLS',
                    style: TextStyle(fontSize: 14, fontFamily: 'Monocraft', fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Connection Status
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _isConnected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(width: 2, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_isConnected 
                            ? (_connectedDevice != null ? 'CONNECTED' : 'SYNCED') 
                            : (_nativeStatusReceived ? 'SEARCHING' : 'LOADING'), 
                            style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Device Info
                  if (_deviceId != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(border: Border.all(width: 1, color: Colors.black)),
                      child: Text(
                        'Device: ${_deviceId!.length > 12 ? '...${_deviceId!.substring(_deviceId!.length - 12)}' : _deviceId}',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ),
                  
                  // Action Buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, 
                      foregroundColor: Colors.black, 
                      side: const BorderSide(width: 2, color: Colors.black),
                    ),
                    onPressed: _openScanner,
                    child: const Text('SCAN FOR DEVICES', style: TextStyle(fontSize: 10)),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, 
                      foregroundColor: Colors.black, 
                      side: const BorderSide(width: 2, color: Colors.black),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SettingsPage(bt: _bt)),
                    ),
                    child: const Text('ADVANCED SETTINGS', style: TextStyle(fontSize: 10)),
                  ),
                  
                  if (_isConnected) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100, 
                        foregroundColor: Colors.black, 
                        side: const BorderSide(width: 2, color: Colors.black),
                      ),
                      onPressed: _forget,
                      child: const Text('DISCONNECT & FORGET', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Debug Info Section
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(width: 1, color: Colors.grey)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Debug Info:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Adapter: $_adapterState', style: const TextStyle(fontSize: 8)),
                        Text('BG Service: ${_bgServiceRunning ? "Running" : "Stopped"}', style: const TextStyle(fontSize: 8)),
                        Text('Status: $_status', style: const TextStyle(fontSize: 8)),
                        if (_permissionStatuses.isNotEmpty)
                          Text(
                            'Perms: ${_permissionStatuses.entries.map((e) => '${e.key.split('.').last}:${e.value?"Y":"N"}').join(', ')}',
                            style: const TextStyle(fontSize: 8),
                          ),
                      ],
                    ),
                  ),
                  
                  // Telemetry Terminal (if connected)
                  if (_isConnected) ...[
                    const SizedBox(height: 12),
                    const Text('Incoming Data:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 150,
                      child: ConnectedTerminal(bt: _bt, maxLines: 100),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A small terminal-like widget that subscribes to the BluetoothService
// raw stream and shows a rolling buffer of recent packets in hex.
class ConnectedTerminal extends StatefulWidget {
  const ConnectedTerminal({super.key, required this.bt, this.maxLines = 100});

  final bt_service.BluetoothService bt;
  final int maxLines;

  @override
  State<ConnectedTerminal> createState() => _ConnectedTerminalState();
}

class _ConnectedTerminalState extends State<ConnectedTerminal> {
  final List<String> _lines = [];
  StreamSubscription<List<int>>? _sub;
  final ScrollController _scroll = ScrollController();
  DateTime? _lastPacketAt;
  Timer? _recentTimer;

  @override
  void initState() {
    super.initState();
    _sub = widget.bt.incomingRaw$.listen((bytes) {
      final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      setState(() {
        _lastPacketAt = DateTime.now();
        _lines.add(s);
        if (_lines.length > widget.maxLines) _lines.removeAt(0);
      });
      // auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recentTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRecent = _lastPacketAt != null && DateTime.now().difference(_lastPacketAt!).inMilliseconds < 2000;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
      child: Scrollbar(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasRecent)
              const Text('— no recent packets —', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: _lines.isEmpty ? 1 : _lines.length,
                itemBuilder: (ctx, i) {
                  if (_lines.isEmpty) return const Text('— no incoming packets yet —', style: TextStyle(fontSize: 10, fontFamily: 'monospace'));
                  return Text(_lines[i], style: const TextStyle(fontSize: 10, fontFamily: 'monospace'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
