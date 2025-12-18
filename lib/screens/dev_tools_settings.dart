// ignore_for_file: unused_field, unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_page.dart';
import '../game/virtual_pet_game.dart';
import '../services/bluetooth_service.dart' as bt_service;
import '../services/foreground_notification.dart';

/// DevToolsSettings - Contains all Bluetooth pairing, telemetry, diagnostic
/// functionality, and pet stat controls.
class DevToolsSettings extends StatefulWidget {
  const DevToolsSettings({
    super.key,
    this.game,
    this.onSyncStatusChanged,
  });

  final VirtualPetGame? game;
  final void Function(bool synced)? onSyncStatusChanged;

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

  // Pet stat rate sliders
  double _hungerDecayRate = 0.01;
  double _happinessGainRate = 0.02;
  double _happinessDecayRate = 0.01;
  
  // Low wellbeing notification threshold (0.0 to 1.0)
  double _lowWellbeingThreshold = 0.25;

  // Stat display update timer
  Timer? _statDisplayTimer;
  
  // Debug: Fake sync override
  bool _fakeSyncEnabled = false;
  bool _fakeSyncValue = false;

  @override
  void initState() {
    super.initState();
    _init();
    _bt.init();
    _loadPersisted();
    _loadPersistedRates();
    _loadFakeSyncSettings();
    _userActionSub = _bt.userAction$.listen((a) => _handleUserAction(a));
    _connSub = _bt.connectedDevice$.listen((d) {
      setState(() {
        _connectedDevice = d;
        if (d != null) {
          _isConnected = true;
          _deviceId = d.remoteId.str;
          _status = 'LINKED';
          _notifySyncStatus(true);
        } else {
          _isConnected = false;
          _deviceId = null;
          _status = 'SEARCHING';
          _notifySyncStatus(false);
        }
      });
      if (d != null) {
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
      _notifySyncStatus(connected);
      if (connected && _deviceId == null) {
        _loadPersistedDeviceId();
      }
    });
    _incomingSub = _bt.incomingData$.listen((s) {
      setState(() => _incoming = s);
    });

    // Update stat display every 500ms
    _statDisplayTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statDisplayTimer?.cancel();
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
      _notifySyncStatus(true);
    }
  }

  Future<void> _loadPersistedRates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hungerDecayRate = prefs.getDouble('pet_hunger_decay_rate') ?? 0.01;
      _happinessGainRate = prefs.getDouble('pet_happiness_gain_rate') ?? 0.02;
      _happinessDecayRate = prefs.getDouble('pet_happiness_decay_rate') ?? 0.01;
      _lowWellbeingThreshold = prefs.getDouble('pet_low_wellbeing_threshold') ?? 0.25;
    });
    // Update game pet stats threshold
    widget.game?.currentPet.stats.lowWellbeingThreshold = _lowWellbeingThreshold;
  }

  Future<void> _saveRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pet_hunger_decay_rate', _hungerDecayRate);
    await prefs.setDouble('pet_happiness_gain_rate', _happinessGainRate);
    await prefs.setDouble('pet_happiness_decay_rate', _happinessDecayRate);
    await prefs.setDouble('pet_low_wellbeing_threshold', _lowWellbeingThreshold);
  }

  Future<void> _loadPersistedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('saved_device_id');
    if (id != null) {
      setState(() => _deviceId = id);
    }
  }

  Future<void> _loadFakeSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fakeSyncEnabled = prefs.getBool('debug_fake_sync_enabled') ?? false;
      _fakeSyncValue = prefs.getBool('debug_fake_sync_value') ?? false;
    });
  }

  Future<void> _saveFakeSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_fake_sync_enabled', _fakeSyncEnabled);
    await prefs.setBool('debug_fake_sync_value', _fakeSyncValue);
  }

  void _notifySyncStatus(bool realStatus) {
    // If fake sync is enabled, use fake value; otherwise use real status
    final effectiveStatus = _fakeSyncEnabled ? _fakeSyncValue : realStatus;
    widget.onSyncStatusChanged?.call(effectiveStatus);
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
    widget.onSyncStatusChanged?.call(false);
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

  Widget _buildStatRateInput({
    required String label,
    required double currentRate,
    required ValueChanged<double> onApply,
  }) {
    // Display current rate as "X% over 10s"
    final percentOver10s = (currentRate * 10 * 100).toStringAsFixed(1);
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                Text('$percentOver10s% / 10s  (${(currentRate * 100).toStringAsFixed(3)}%/s)', 
                  style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
              ),
              onPressed: () => _showRateEditDialog(label, currentRate, onApply),
              child: const Text('EDIT', style: TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRateEditDialog(String label, double currentRate, ValueChanged<double> onApply) async {
    final percentController = TextEditingController(text: (currentRate * 10 * 100).toStringAsFixed(1));
    final secondsController = TextEditingController(text: '10');
    
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set rate as N% over T seconds:', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: percentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Percent',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('over'),
                ),
                Expanded(
                  child: TextField(
                    controller: secondsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Seconds',
                      suffixText: 's',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final percent = double.parse(percentController.text);
                final seconds = double.parse(secondsController.text);
                if (seconds > 0 && percent >= 0) {
                  final rate = (percent / 100.0) / seconds;
                  Navigator.of(ctx).pop(rate);
                }
              } catch (e) {
                // Invalid input
              }
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      onApply(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.game?.getStatValues();
    final hunger = stats?['hunger'] ?? 0.0;
    final happiness = stats?['happiness'] ?? 0.0;
    final wellbeing = stats?['wellbeing'] ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'SETTINGS',
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pet Stats Section
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(width: 2, color: Colors.black),
                    color: const Color(0xFFF5F5F5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PET STATS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildStatBar('Hunger', hunger, Colors.orange),
                      const SizedBox(height: 4),
                      _buildStatBar('Happiness', happiness, Colors.pink),
                      const SizedBox(height: 4),
                      _buildStatBar('Wellbeing', wellbeing, Colors.green),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade100,
                                foregroundColor: Colors.black,
                                side: const BorderSide(width: 1, color: Colors.black),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              onPressed: () => widget.game?.feedPet(),
                              child: const Text('FEED', style: TextStyle(fontSize: 10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade100,
                                foregroundColor: Colors.black,
                                side: const BorderSide(width: 1, color: Colors.black),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              onPressed: () => widget.game?.resetPetStats(),
                              child: const Text('RESET', style: TextStyle(fontSize: 10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
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
                    MaterialPageRoute(builder: (_) => SettingsPage(bt: _bt, game: widget.game)),
                  ).then((_) {
                    // Reload fake sync settings after returning from Advanced Settings
                    _loadFakeSyncSettings().then((_) {
                      _notifySyncStatus(_isConnected);
                    });
                  }),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 10)),
        ),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(width: 1, color: Colors.black),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 35,
          child: Text('${(value * 100).toStringAsFixed(0)}%', 
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            textAlign: TextAlign.right,
          ),
        ),
      ],
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
