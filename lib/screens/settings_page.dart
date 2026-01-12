import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/device/device_service.dart';
import '../services/cloud/cloud_service.dart';
import '../game/virtual_pet_game.dart';

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
  int _flappyCoinDivisor = 1;
  
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
      _flappyCoinDivisor = prefs.getInt('flappy_coin_divisor') ?? 1;
    });
  }
  
  Future<void> _saveRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hunger_decay_rate', _hungerDecayRate);
    await prefs.setDouble('happiness_gain_rate', _happinessGainRate);
    await prefs.setDouble('happiness_decay_rate', _happinessDecayRate);
    await prefs.setDouble('low_wellbeing_threshold', _lowWellbeingThreshold);
    await prefs.setInt('flappy_coin_divisor', _flappyCoinDivisor);
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
  
  Widget _buildStatRateInput({
    required String label,
    required double currentRate,
    required ValueChanged<double> onApply,
  }) {
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
  
  Widget _buildThresholdInput({
    required String label,
    required double currentThreshold,
    required ValueChanged<double> onApply,
  }) {
    // Display current threshold as percentage
    final percentValue = (currentThreshold * 100).toStringAsFixed(0);
    
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
                Text('$percentValue%', 
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
              onPressed: () => _showThresholdEditDialog(label, currentThreshold, onApply),
              child: const Text('EDIT', style: TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showThresholdEditDialog(String label, double currentThreshold, ValueChanged<double> onApply) async {
    final percentController = TextEditingController(text: (currentThreshold * 100).toStringAsFixed(0));
    
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set threshold percentage (0-100%):', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 12),
            TextField(
              controller: percentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Percentage',
                suffixText: '%',
                border: OutlineInputBorder(),
                isDense: true,
              ),
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
                if (percent >= 0 && percent <= 100) {
                  final threshold = (percent / 100.0).clamp(0.0, 1.0);
                  Navigator.of(ctx).pop(threshold);
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Settings', style: TextStyle(fontSize: 14))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Stat Rate Controls
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.black),
              color: const Color(0xFFF5F5F5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('STAT RATES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('(${(_hungerDecayRate * 100).toStringAsFixed(3)}%/s, ${(_happinessGainRate * 100).toStringAsFixed(3)}%/s, ${(_happinessDecayRate * 100).toStringAsFixed(3)}%/s)', 
                      style: const TextStyle(fontSize: 8, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildStatRateInput(
                  label: 'Hunger Decay',
                  currentRate: _hungerDecayRate,
                  onApply: (rate) {
                    setState(() => _hungerDecayRate = rate);
                    widget.game?.setStatRates(
                      hungerDecayRate: _hungerDecayRate,
                      happinessGainRate: _happinessGainRate,
                      happinessDecayRate: _happinessDecayRate,
                    );
                    _saveRates();
                  },
                ),
                const SizedBox(height: 8),
                _buildStatRateInput(
                  label: 'Happiness Gain (synced)',
                  currentRate: _happinessGainRate,
                  onApply: (rate) {
                    setState(() => _happinessGainRate = rate);
                    widget.game?.setStatRates(
                      hungerDecayRate: _hungerDecayRate,
                      happinessGainRate: _happinessGainRate,
                      happinessDecayRate: _happinessDecayRate,
                    );
                    _saveRates();
                  },
                ),
                const SizedBox(height: 8),
                _buildStatRateInput(
                  label: 'Happiness Decay (not synced)',
                  currentRate: _happinessDecayRate,
                  onApply: (rate) {
                    setState(() => _happinessDecayRate = rate);
                    widget.game?.setStatRates(
                      hungerDecayRate: _hungerDecayRate,
                      happinessGainRate: _happinessGainRate,
                      happinessDecayRate: _happinessDecayRate,
                    );
                    _saveRates();
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Low Wellbeing Notification Threshold
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.black),
              color: const Color(0xFFF5F5F5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NOTIFICATIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildThresholdInput(
                  label: 'Low Wellbeing Alert Threshold',
                  currentThreshold: _lowWellbeingThreshold,
                  onApply: (threshold) {
                    setState(() => _lowWellbeingThreshold = threshold);
                    widget.game?.currentPet.stats.lowWellbeingThreshold = threshold;
                    _saveRates();
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Notify when wellbeing drops to ${(_lowWellbeingThreshold * 100).toStringAsFixed(0)}% or below',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Flappy Bird Game Settings
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.black),
              color: Colors.cyan.shade50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FLAPPY BOB GAME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Coin Divisor', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                          Text('Silver = Score / Divisor', style: TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: _flappyCoinDivisor > 1 ? () {
                            setState(() => _flappyCoinDivisor--);
                            _saveRates();
                          } : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$_flappyCoinDivisor', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: _flappyCoinDivisor < 20 ? () {
                            setState(() => _flappyCoinDivisor++);
                            _saveRates();
                          } : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Score 10 = ${10 ~/ _flappyCoinDivisor} silver coins',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Cloud Configuration
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.purple),
              color: Colors.purple.shade50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CLOUD SYNC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('${_cloud.pendingEventCount} pending', 
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(width: 1, color: Colors.black26),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Base URL:', style: TextStyle(fontSize: 9, color: Colors.grey)),
                      Text(_cloudBaseUrl.isEmpty ? '(not set)' : _cloudBaseUrl,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text('Device Token:', style: TextStyle(fontSize: 9, color: Colors.grey)),
                      Text(_cloudDeviceToken.isEmpty ? '(not set)' : _cloudDeviceToken,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade100,
                          foregroundColor: Colors.black,
                          side: const BorderSide(width: 1, color: Colors.black),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        onPressed: _showCloudConfigDialog,
                        child: const Text('CONFIGURE', style: TextStyle(fontSize: 9)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.black,
                          side: const BorderSide(width: 1, color: Colors.black),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        onPressed: () async {
                          await _cloud.flushQueue();
                          setState(() {}); // Refresh pending count
                        },
                        child: const Text('FLUSH QUEUE', style: TextStyle(fontSize: 9)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
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
                    ? 'SYNCED' 
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
          
          // Debug: Fake Sync Toggle
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.orange),
              color: Colors.orange.shade50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DEBUG: FAKE SYNC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Checkbox(
                      value: _fakeSyncEnabled,
                      onChanged: (val) {
                        setState(() => _fakeSyncEnabled = val ?? false);
                        _saveFakeSyncSettings();
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Text('Override Sync Status', style: TextStyle(fontSize: 10)),
                  ],
                ),
                if (_fakeSyncEnabled) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Radio<bool>(
                        value: true,
                        groupValue: _fakeSyncValue,
                        onChanged: (val) {
                          setState(() => _fakeSyncValue = val ?? true);
                          _saveFakeSyncSettings();
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('SYNCED', style: TextStyle(fontSize: 10, color: Colors.green)),
                      const SizedBox(width: 16),
                      Radio<bool>(
                        value: false,
                        groupValue: _fakeSyncValue,
                        onChanged: (val) {
                          setState(() => _fakeSyncValue = val ?? false);
                          _saveFakeSyncSettings();
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('NOT SYNCED', style: TextStyle(fontSize: 10, color: Colors.red)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
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
              height: 200,
              child: ConnectedTerminal(device: widget.device, maxLines: 100),
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

// A small terminal-like widget that subscribes to the BluetoothService
// raw stream and shows a rolling buffer of recent packets in hex.
class ConnectedTerminal extends StatefulWidget {
  const ConnectedTerminal({super.key, required this.device, this.maxLines = 100});

  final DeviceService device;
  final int maxLines;

  @override
  State<ConnectedTerminal> createState() => _ConnectedTerminalState();
}

class _ConnectedTerminalState extends State<ConnectedTerminal> {
  final List<String> _lines = [];
  StreamSubscription<List<int>>? _sub;
  final ScrollController _scroll = ScrollController();
  DateTime? _lastPacketAt;

  @override
  void initState() {
    super.initState();
    _sub = widget.device.incomingRaw$.listen((bytes) {
      final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      setState(() {
        _lastPacketAt = DateTime.now();
        _lines.add(s);
        if (_lines.length > widget.maxLines) _lines.removeAt(0);
      });
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
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRecent = _lastPacketAt != null && DateTime.now().difference(_lastPacketAt!).inMilliseconds < 2000;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasRecent)
            const Text('— no recent packets —', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
          Expanded(
            child: Scrollbar(
              child: ListView.builder(
                controller: _scroll,
                itemCount: _lines.isEmpty ? 1 : _lines.length,
                itemBuilder: (ctx, i) {
                  if (_lines.isEmpty) return const Text('— no incoming packets yet —', style: TextStyle(fontSize: 10, fontFamily: 'monospace'));
                  return Text(_lines[i], style: const TextStyle(fontSize: 10, fontFamily: 'monospace'));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
