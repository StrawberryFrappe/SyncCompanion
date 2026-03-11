import 'dart:async';
import 'package:flutter/material.dart';

import 'package:Therapets/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/device/device_service.dart';
import '../../services/cloud/cloud_service.dart';
import '../../game/virtual_pet_game.dart';
import '../pulse_oximeter/pulse_oximeter_screen.dart';
import '../temperature_sensor/temperature_sensor_screen.dart';
import 'token_scanner_page.dart';

import 'sections/stat_rates_section.dart';
import 'sections/notifications_section.dart';
import 'sections/cloud_sync_section.dart';
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
  bool _loading = true;
  bool _isConnected = false;
  
  // Stat rates (defaults: 6h decay, 2h gain)
  double _hungerDecayRate = 0.0000463;
  double _happinessGainRate = 0.0001389;
  double _happinessDecayRate = 0.0000463;
  double _lowWellbeingThreshold = 0.25;
  
  // Debug: Fake sync
  bool _fakeSyncEnabled = false;
  bool _fakeSyncValue = false;
  
  // Cloud configuration
  final CloudService _cloud = CloudService();
  String _cloudBaseUrl = '';
  String _cloudDeviceToken = '';
  
  Timer? _statDisplayTimer;
  StreamSubscription<DeviceConnectionState>? _nativeConnSub;

  @override
  void initState() {
    super.initState();
    _loadPersisted();
    _loadPersistedRates();
    _loadFakeSyncSettings();
    _loadCloudConfig();
    
    _nativeConnSub = widget.device.connectionState$.listen((state) {
      if (!mounted) return;
      final connected = state == DeviceConnectionState.connected;
      setState(() {
        _isConnected = connected;
      });
      if (connected) {
        _loadPersistedDeviceId();
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

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('saved_device_id');
    setState(() {
      if (id != null) {
        _isConnected = true;
      }
      _loading = false;
    });
  }
  
  Future<void> _loadPersistedRates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hungerDecayRate = prefs.getDouble('pet_hunger_decay_rate') ?? 0.0000463;
      _happinessGainRate = prefs.getDouble('pet_happiness_gain_rate') ?? 0.0001389;
      _happinessDecayRate = prefs.getDouble('pet_happiness_decay_rate') ?? 0.0000463;
      _lowWellbeingThreshold = prefs.getDouble('pet_low_wellbeing_threshold') ?? 0.25;
    });
  }
  
  Future<void> _saveRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pet_hunger_decay_rate', _hungerDecayRate);
    await prefs.setDouble('pet_happiness_gain_rate', _happinessGainRate);
    await prefs.setDouble('pet_happiness_decay_rate', _happinessDecayRate);
    await prefs.setDouble('pet_low_wellbeing_threshold', _lowWellbeingThreshold);
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
        title: Text(AppLocalizations.of(context)!.cloudConfiguration, style: const TextStyle(fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.cloudConfigDesc,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.baseUrl,
                  hintText: 'http://192.168.1.100:8080',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: tokenController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.deviceToken,
                  hintText: 'YOUR_DEVICE_ACCESS_TOKEN',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final token = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (context) => const TokenScannerPage(),
                        ),
                      );
                      
                      if (token != null && mounted) {
                        tokenController.text = token;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.tokenScanned),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
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
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              _saveCloudConfig(urlController.text, tokenController.text);
              Navigator.of(ctx).pop();
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
  


  Future<void> _loadPersistedDeviceId() async {
    // No-op: device ID loading is now handled elsewhere
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.advancedSettings, style: const TextStyle(fontSize: 14))),
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
          ),
          
          // Device-specific buttons (only when connected)
          if (_isConnected) ...[
            const SizedBox(height: 12),
            // Show sensor button based on device type
            if (widget.device.deviceType == DeviceType.max30100)
              // Pulse Oximeter Button
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
                label: Text(AppLocalizations.of(context)!.pulseOximeter, style: const TextStyle(fontSize: 12, fontFamily: 'Monocraft')),
              )
            else if (widget.device.deviceType == DeviceType.gy906)
              // Temperature Sensor Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A2A1A),
                  foregroundColor: const Color(0xFFFF6600),
                  side: const BorderSide(width: 2, color: Color(0xFFAA5500)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TemperatureSensorScreen(device: widget.device),
                  ),
                ),
                icon: const Icon(Icons.thermostat),
                label: Text(AppLocalizations.of(context)!.temperatureSensor, style: const TextStyle(fontSize: 12, fontFamily: 'Monocraft')),
              ),
            const SizedBox(height: 8),
            // Raw Data Terminal Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[900],
                foregroundColor: Colors.white,
                side: const BorderSide(width: 2, color: Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _RawDataTerminalScreen(device: widget.device),
                ),
              ),
              icon: const Icon(Icons.terminal),
              label: Text(AppLocalizations.of(context)!.rawDataTerminal, style: const TextStyle(fontSize: 12, fontFamily: 'Monocraft')),
            ),
          ],
          
          const SizedBox(height: 24),
          const Divider(thickness: 2),
          const SizedBox(height: 12),
          
          // Reset Stats Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[100],
              foregroundColor: Colors.red[900],
              side: BorderSide(width: 2, color: Colors.red[900]!),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(AppLocalizations.of(context)!.resetStatsTitle, style: const TextStyle(fontSize: 14)),
                  content: Text(AppLocalizations.of(context)!.resetStatsConfirm, style: const TextStyle(fontSize: 12)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.of(context)!.reset, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              );
              
              if (confirmed == true) {
                widget.game?.resetPetStats();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.petStatsResetSuccess)),
                  );
                }
              }
            },
            icon: const Icon(Icons.restart_alt),
            label: Text(AppLocalizations.of(context)!.resetStats, style: const TextStyle(fontSize: 12, fontFamily: 'Monocraft', fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),

        ],
      ),
    );
  }
}

/// Full-screen raw data terminal view.
class _RawDataTerminalScreen extends StatelessWidget {
  final DeviceService device;
  
  const _RawDataTerminalScreen({required this.device});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.rawDataTerminalTitle, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TelemetryTerminal(device: device, maxLines: 500),
      ),
    );
  }
}
