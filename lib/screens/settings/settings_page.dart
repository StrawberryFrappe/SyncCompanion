import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/device/device_service.dart';
import '../../services/cloud/cloud_service.dart';
import '../../game/virtual_pet_game.dart';
import '../pulse_oximeter/pulse_oximeter_screen.dart';

import 'sections/stat_rates_section.dart';
import 'sections/notifications_section.dart';
import 'sections/flappy_game_section.dart';
import 'sections/cloud_sync_section.dart';
import 'sections/connection_status_section.dart';
import 'sections/debug_section.dart';
import 'widgets/telemetry_terminal.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.device, this.game});

  final DeviceService device;
  final VirtualPetGame? game;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifShowData = true;
  bool _loading = true;
  bool _isConnected = false;
  String? _deviceId;
  
  // Stat rates
  double _hungerDecayRate = 0.01;
  double _happinessGainRate = 0.02;
  double _happinessDecayRate = 0.01;
  double _lowWellbeingThreshold = 0.25;
  double _flappyCoinMultiplier = 1.0;
  
  // Debug: Fake sync
  bool _fakeSyncEnabled = false;
  bool _fakeSyncValue = false;
  
  // Debug info
  String _adapterState = 'unknown';
  Map<String, bool> _permissionStatuses = {};
  bool _bgServiceRunning = false;
  String _status = 'SEARCHING';
  bool _nativeStatusReceived = false;
  
  // Cloud configuration
  final CloudService _cloud = CloudService();
  String _cloudBaseUrl = '';
  String _cloudDeviceToken = '';
  
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  Timer? _statDisplayTimer;
  StreamSubscription<DeviceConnectionState>? _nativeConnSub;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadPersisted();
    _loadPersistedRates();
    _loadFakeSyncSettings();
    _loadCloudConfig();
    _loadDebugInfo();
    
    _nativeConnSub = widget.device.connectionState$.listen((state) {
      if (!mounted) return;
      final connected = state == DeviceConnectionState.connected;
      setState(() {
        _isConnected = connected;
        _nativeStatusReceived = true;
        _status = connected ? 'SYNCED' : 'SEARCHING';
      });
      if (connected) {
        _loadPersistedDeviceId();
      } else {
        setState(() => _deviceId = null);
      }
    });
    
    // Refresh stats display periodically
    _statDisplayTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _statDisplayTimer?.cancel();
    _nativeConnSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool('notif_show_data');
    setState(() {
      _notifShowData = v == null ? false : v;
      _loading = false;
    });
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('saved_device_id');
    if (id != null) {
      setState(() {
        _isConnected = true;
        _deviceId = id;
      });
    }
  }
  
  Future<void> _loadPersistedRates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hungerDecayRate = prefs.getDouble('hunger_decay_rate') ?? 0.01;
      _happinessGainRate = prefs.getDouble('happiness_gain_rate') ?? 0.02;
      _happinessDecayRate = prefs.getDouble('happiness_decay_rate') ?? 0.01;
      _lowWellbeingThreshold = prefs.getDouble('low_wellbeing_threshold') ?? 0.25;
      _flappyCoinMultiplier = prefs.getDouble('flappy_coin_multiplier') ?? 1.0;
    });
  }
  
  Future<void> _saveRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hunger_decay_rate', _hungerDecayRate);
    await prefs.setDouble('happiness_gain_rate', _happinessGainRate);
    await prefs.setDouble('happiness_decay_rate', _happinessDecayRate);
    await prefs.setDouble('low_wellbeing_threshold', _lowWellbeingThreshold);
    await prefs.setDouble('flappy_coin_multiplier', _flappyCoinMultiplier);
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
  
  void _loadCloudConfig() {
    setState(() {
      _cloudBaseUrl = _cloud.baseUrl;
      _cloudDeviceToken = _cloud.deviceToken;
    });
  }
  
  Future<void> _saveCloudConfig(String baseUrl, String deviceToken) async {
    await _cloud.updateConfig(baseUrl: baseUrl, deviceToken: deviceToken);
    setState(() {
      _cloudBaseUrl = baseUrl;
      _cloudDeviceToken = deviceToken;
    });
  }
  
  Future<void> _showCloudConfigDialog() async {
    final urlController = TextEditingController(text: _cloudBaseUrl);
    final tokenController = TextEditingController(text: _cloudDeviceToken);
    
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cloud Configuration', style: TextStyle(fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configure the endpoint URL and device token for cloud sync.',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'http://192.168.1.100:8080',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: 'Device Token',
                  hintText: 'YOUR_DEVICE_ACCESS_TOKEN',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Text(
                'Full endpoint: ${urlController.text}/api/v1/${tokenController.text}/telemetry',
                style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveCloudConfig(urlController.text, tokenController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _loadDebugInfo() async {
    try {
      final result = await _platform.invokeMethod<Map>('getDebugInfo');
      if (result != null) {
        setState(() {
          _adapterState = result['adapterState'] ?? 'unknown';
          _bgServiceRunning = result['serviceRunning'] ?? false;
          final perms = result['permissions'];
          if (perms is Map) {
            _permissionStatuses = perms.map((k, v) => MapEntry(k.toString(), v == true));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPersistedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('saved_device_id');
    if (id != null) {
      setState(() => _deviceId = id);
    }
  }

  Future<void> _setShowData(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_show_data', v);
    setState(() => _notifShowData = v);
    try {
      await widget.device.setNotifShowData(v);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Settings', style: TextStyle(fontSize: 14))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Stat Rate Controls
          StatRatesSection(
            hungerDecayRate: _hungerDecayRate,
            happinessGainRate: _happinessGainRate,
            happinessDecayRate: _happinessDecayRate,
            onHungerDecayChanged: (rate) {
              setState(() => _hungerDecayRate = rate);
              widget.game?.setStatRates(
                hungerDecayRate: _hungerDecayRate,
                happinessGainRate: _happinessGainRate,
                happinessDecayRate: _happinessDecayRate,
              );
              _saveRates();
            },
            onHappinessGainChanged: (rate) {
              setState(() => _happinessGainRate = rate);
              widget.game?.setStatRates(
                hungerDecayRate: _hungerDecayRate,
                happinessGainRate: _happinessGainRate,
                happinessDecayRate: _happinessDecayRate,
              );
              _saveRates();
            },
            onHappinessDecayChanged: (rate) {
              setState(() => _happinessDecayRate = rate);
              widget.game?.setStatRates(
                hungerDecayRate: _hungerDecayRate,
                happinessGainRate: _happinessGainRate,
                happinessDecayRate: _happinessDecayRate,
              );
              _saveRates();
            },
          ),
          
          const SizedBox(height: 12),
          
          // Notifications
          NotificationsSection(
            lowWellbeingThreshold: _lowWellbeingThreshold,
            onThresholdChanged: (threshold) {
              setState(() => _lowWellbeingThreshold = threshold);
              widget.game?.currentPet.stats.lowWellbeingThreshold = threshold;
              _saveRates();
            },
          ),
          
          const SizedBox(height: 12),
          
          // Flappy Bob Game
          FlappyGameSection(
            coinMultiplier: _flappyCoinMultiplier,
            onMultiplierChanged: (val) {
              setState(() => _flappyCoinMultiplier = val);
              _saveRates();
            },
          ),
          
          const SizedBox(height: 12),
          
          // Cloud Sync
          CloudSyncSection(
            cloud: _cloud,
            baseUrl: _cloudBaseUrl,
            deviceToken: _cloudDeviceToken,
            onConfigure: _showCloudConfigDialog,
            onFlushQueue: () async {
              await _cloud.flushQueue();
              setState(() {}); // Refresh pending count
            },
          ),
          const SizedBox(height: 12),
          
          // Connection Status
          ConnectionStatusSection(
            isConnected: _isConnected,
            nativeStatusReceived: _nativeStatusReceived,
            deviceId: _deviceId,
          ),
          
          // Pulse Oximeter Button (only when connected)
          if (_isConnected) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A1A),
                foregroundColor: const Color(0xFF00FF00),
                side: const BorderSide(width: 2, color: Color(0xFF00AA00)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PulseOximeterScreen(device: widget.device),
                ),
              ),
              icon: const Icon(Icons.monitor_heart),
              label: const Text('PULSE OXIMETER', style: TextStyle(fontSize: 12, fontFamily: 'Monocraft')),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Debug Section
          DebugSection(
            fakeSyncEnabled: _fakeSyncEnabled,
            fakeSyncValue: _fakeSyncValue,
            onFakeSyncEnabledChanged: (val) {
              setState(() => _fakeSyncEnabled = val ?? false);
              _saveFakeSyncSettings();
            },
            onFakeSyncValueChanged: (val) {
              if (val != null) {
                setState(() => _fakeSyncValue = val);
                _saveFakeSyncSettings();
              }
            },
            adapterState: _adapterState,
            bgServiceRunning: _bgServiceRunning,
            status: _status,
            permissionStatuses: _permissionStatuses,
          ),
          
          // Telemetry Terminal (if connected)
          if (_isConnected) ...[
            const SizedBox(height: 12),
            const Text('Incoming Data:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SizedBox(
              height: 200,
              child: TelemetryTerminal(device: widget.device, maxLines: 100),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Notification Settings
          SwitchListTile(
            title: const Text('Notification: show live data', style: TextStyle(fontSize: 12)),
            subtitle: const Text('When off, notification shows "Your device is synced"', style: TextStyle(fontSize: 10)),
            value: _notifShowData,
            onChanged: (v) => _setShowData(v),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
