// ignore_for_file: unused_field, unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_page.dart';
import 'sections/pet_stats_section.dart';
import 'widgets/bluetooth_scanner_dialog.dart';
import '../../game/virtual_pet_game.dart';
import '../../services/device/device_service.dart';
import '../../services/notifications/foreground_notification.dart';

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
  final DeviceService _device = DeviceService();
  BluetoothDevice? _connectedDevice;
  String _status = 'SEARCHING';
  
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  String _adapterState = 'unknown';
  Map<String, bool> _permissionStatuses = {};
  bool _bgServiceRunning = false;
  ForegroundNotificationUpdater? _notifUpdater;

  StreamSubscription<BluetoothDevice?>? _connSub;
  StreamSubscription<BluetoothUserAction>? _userActionSub;
  StreamSubscription<DeviceConnectionState>? _connStateSub;

  bool _isConnected = false;
  String? _deviceId;

  // Debug: Fake sync override
  bool _fakeSyncEnabled = false;
  bool _fakeSyncValue = false;

  // Stat display update timer
  Timer? _statDisplayTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _device.init();
    _loadPersisted();
    _loadFakeSyncSettings();
    _userActionSub = _device.userAction$.listen((a) => _handleUserAction(a));
    _connSub = _device.connectedDevice$.listen((d) {
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
    _connStateSub = _device.connectionState$.listen((state) {
      final connected = state == DeviceConnectionState.connected;
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
    _userActionSub?.cancel();
    _connStateSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final enabled = await _platform.invokeMethod('isBluetoothEnabled');
      setState(() => _adapterState = (enabled == true) ? 'ON' : 'OFF');
    } on PlatformException catch (e) {
      debugPrint('isBluetoothEnabled failed: $e');
    }
    try {
      final running = await _platform.invokeMethod('isNativeServiceRunning');
      setState(() => _bgServiceRunning = (running == true));
    } catch (_) {}
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

  void _notifySyncStatus(bool realStatus) {
    final effectiveStatus = _fakeSyncEnabled ? _fakeSyncValue : realStatus;
    widget.onSyncStatusChanged?.call(effectiveStatus);
  }

  Future<void> _handleUserAction(BluetoothUserAction action) async {
    try {
      if (action.type == BluetoothUserActionType.enableBluetooth) {
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
          final enabled = await _device.performEnableBluetooth();
          setState(() => _adapterState = enabled ? 'ON' : 'OFF');
        }
      } else if (action.type == BluetoothUserActionType.requestPermissions) {
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
          final ok = await _device.performRequestPermissions();
          setState(() => _permissionStatuses = _device.permissionStatuses);
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
    await _device.performRequestPermissions();
    setState(() => _permissionStatuses = _device.permissionStatuses);
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
      debugPrint('startNativeService failed: $e');
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Native service failed', style: TextStyle(fontSize: 12)),
        content: const Text('Could not start the native BLE foreground service. Please ensure the app has the required permissions.', style: TextStyle(fontSize: 10)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK', style: TextStyle(fontSize: 10))),
        ],
      ));
    }
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    try {
      setState(() => _status = 'CONNECTING');
      await _device.connect(device);
    } catch (e) {
      setState(() => _status = 'SEARCHING');
    }
  }

  Future<void> _forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_device_id');
    try {
      await _device.disconnect();
    } catch (_) {}
    setState(() {
      _status = 'SEARCHING';
      _connectedDevice = null;
      _isConnected = false;
      _deviceId = null;
    });
    widget.onSyncStatusChanged?.call(false);
  }

  void _openScanner() {
    showDialog(
      context: context,
      builder: (c) => BluetoothScannerDialog(
        device: _device,
        connectedDevice: _connectedDevice,
        persistedDeviceId: _deviceId,
        onForget: _forget,
        onConnect: _connectTo,
      ),
    );
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
                // Pet Stats Section (extracted)
                PetStatsSection(
                  hunger: hunger,
                  happiness: happiness,
                  wellbeing: wellbeing,
                  onFeed: () => widget.game?.feedPet(),
                  onReset: () => widget.game?.resetPetStats(),
                  onAddGold: () => widget.game?.currentPet.stats.addGold(100),
                  onAddSilver: () => widget.game?.currentPet.stats.addSilver(100),
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
                    MaterialPageRoute(builder: (_) => SettingsPage(device: _device, game: widget.game)),
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
}
