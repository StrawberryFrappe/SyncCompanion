// ignore_for_file: unused_field, unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:Therapets/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_page.dart';
import 'sections/pet_stats_section.dart';
import 'widgets/bluetooth_scanner_dialog.dart';
import '../../game/virtual_pet_game.dart';
import '../../services/device/device_service.dart';
import '../../services/locale_service.dart';
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

  StreamSubscription<BluetoothUserAction>? _userActionSub;
  StreamSubscription? _connSub;
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
    
    // Check current state immediately (popup might open when already connected)
    final currentState = _device.currentState;
    if (currentState == DeviceConnectionState.connected) {
      _isConnected = true;
      _status = 'LINKED';
      _loadPersistedDeviceId();
    }
    
    // Unified state listener - single source of truth for connection state
    _connStateSub = _device.connectionState$.listen((state) {
      final connected = state == DeviceConnectionState.connected;
      
      setState(() {
        _isConnected = connected;
        if (connected) {
          _status = 'LINKED';
          _notifySyncStatus(true);
        } else {
          _status = 'SEARCHING';
          _notifySyncStatus(false);
        }
      });
      
      if (connected) {
        _startBackgroundTask();
        _loadPersistedDeviceId();
      }
    });

    // Update stat display every 500ms
    _statDisplayTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });

    // Subscribe to connected device updates
    _connSub = _device.connectedDevice$.listen((device) {
      if (mounted) setState(() => _connectedDevice = device);
    });
  }

  @override
  void dispose() {
    _statDisplayTimer?.cancel();
    _notifUpdater?.stop();
    _userActionSub?.cancel();
    _connSub?.cancel();
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
    // Don't optimistically set connected=true here. Wait for real state from DeviceService.
    if (id != null) {
      setState(() {
        _deviceId = id;
        // Status remains SEARCHING until we get actual connection confirmation
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
        final l10n = AppLocalizations.of(context)!;
        final pressed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.bluetoothDisabled, style: const TextStyle(fontSize: 12)),
            content: Text(l10n.bluetoothNeeded, style: const TextStyle(fontSize: 10)),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l10n.cancel, style: const TextStyle(fontSize: 10))),
              TextButton(onPressed: () => Navigator.of(c).pop(true), child: Text(l10n.enableBluetooth, style: const TextStyle(fontSize: 10))),
            ],
          ),
        );
        if (pressed == true) {
          final enabled = await _device.performEnableBluetooth();
          setState(() => _adapterState = enabled ? 'ON' : 'OFF');
        }
      } else if (action.type == BluetoothUserActionType.requestPermissions) {
        final l10n2 = AppLocalizations.of(context)!;
        final pressed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n2.permissionsRequired, style: const TextStyle(fontSize: 12)),
            content: Text(l10n2.permissionsNeededBle, style: const TextStyle(fontSize: 10)),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l10n2.cancel, style: const TextStyle(fontSize: 10))),
              TextButton(onPressed: () => Navigator.of(c).pop(true), child: Text(l10n2.request, style: const TextStyle(fontSize: 10))),
            ],
          ),
        );
        if (pressed == true) {
          final ok = await _device.performRequestPermissions();
          setState(() => _permissionStatuses = _device.permissionStatuses);
          if (!ok) {
            final l10n3 = AppLocalizations.of(context)!;
            await showDialog<void>(context: context, builder: (c) => AlertDialog(
              title: Text(l10n3.permissionsRequired, style: const TextStyle(fontSize: 12)),
              content: Text(l10n3.permissionsDenied, style: const TextStyle(fontSize: 10)),
              actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: Text(l10n3.ok, style: const TextStyle(fontSize: 10)))],
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
      final l10n = AppLocalizations.of(context)!;
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: Text(l10n.permissionsRequired, style: const TextStyle(fontSize: 12)),
        content: Text(l10n.permissionsRequiredNative, style: const TextStyle(fontSize: 10)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: Text(l10n.ok, style: const TextStyle(fontSize: 10))),
        ],
      ));
      return;
    }

    try {
      await _platform.invokeMethod('startNativeService');
      setState(() => _bgServiceRunning = true);
    } catch (e) {
      debugPrint('startNativeService failed: $e');
      final l10n = AppLocalizations.of(context)!;
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: Text(l10n.nativeServiceFailed, style: const TextStyle(fontSize: 12)),
        content: Text(l10n.nativeServiceFailedDesc, style: const TextStyle(fontSize: 10)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: Text(l10n.ok, style: const TextStyle(fontSize: 10))),
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
    // BluetoothService.forget() handles pref removal and clearing internal state
    // preventing the "stale saved ID" issue that causes WAITING status.
    await _device.forget();
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
    final l10n = AppLocalizations.of(context)!;
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
                Expanded(
                  child: Text(
                    l10n.settingsTitle,
                    style: const TextStyle(fontSize: 14, fontFamily: 'Monocraft', fontWeight: FontWeight.bold),
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
                  onAddGold: () => widget.game?.currentPet.stats.addGold(100),
                  onAddSilver: () => widget.game?.currentPet.stats.addSilver(100),
                ),
                
                const SizedBox(height: 12),

                // Language Picker
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(width: 2, color: Colors.black),
                    color: const Color(0xFFF5F5F5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.language, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLanguageFlag(
                            assetPath: 'assets/images/UK.png',
                            locale: const Locale('en'),
                            isSelected: LocaleService().locale.languageCode == 'en',
                          ),
                          const SizedBox(width: 16),
                          _buildLanguageFlag(
                            assetPath: 'assets/images/Chile.png',
                            locale: const Locale('es'),
                            isSelected: LocaleService().locale.languageCode == 'es',
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
                  child: Text(l10n.scanForDevices, style: const TextStyle(fontSize: 10)),
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
                  child: Text(l10n.advancedSettings, style: const TextStyle(fontSize: 10)),
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
                    child: Text(l10n.disconnectAndForget, style: const TextStyle(fontSize: 10)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageFlag({
    required String assetPath,
    required Locale locale,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        LocaleService().setLocale(locale);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            width: isSelected ? 3 : 1,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.withAlpha(25) : Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            assetPath,
            width: 48,
            height: 32,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}
