import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/virtual_pet_game.dart';
import 'dev_tools_settings.dart';

/// GameScreen - The main screen of the app.
/// Uses a Stack to layer the Flame game underneath a minimal HUD overlay.
/// Handles app lifecycle to persist and restore pet stats.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final VirtualPetGame _game;
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  
  bool _isDeviceSynced = false;
  StreamSubscription<dynamic>? _syncSub;
  
  // For periodic stat saving while app is active
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = VirtualPetGame();
    _initializeGame();
    _listenToSyncStatus();
    
    // Auto-save stats every 30 seconds while app is active
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveStats();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _syncSub?.cancel();
    _saveStats(); // Save on dispose
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('[GameScreen] Lifecycle state changed: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
        // App fully backgrounded - save current state with timestamp
        // NOTE: Only save on 'paused', not 'inactive'/'hidden' which also fire when RETURNING
        print('[GameScreen] Saving stats (app paused/backgrounded)');
        _saveStats();
        break;
      case AppLifecycleState.resumed:
        // App returning to foreground - restore and apply background updates
        print('[GameScreen] Restoring stats (returning to foreground)');
        _restoreStats();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // These states happen both when leaving AND returning - don't save here
        print('[GameScreen] Lifecycle transition state: $state (no action)');
        break;
    }
  }

  Future<void> _initializeGame() async {
    await _loadSyncStatus();
    await _loadPersistedRates();
    await _restoreStats();
  }

  Future<void> _loadSyncStatus() async {
    // Check if we have a persisted device (means we're synced)
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('saved_device_id');
    setState(() {
      _isDeviceSynced = deviceId != null;
    });
    _game.setSyncStatus(_isDeviceSynced);
  }

  Future<void> _loadPersistedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final hungerRate = prefs.getDouble('pet_hunger_decay_rate');
    final happinessGain = prefs.getDouble('pet_happiness_gain_rate');
    final happinessDecay = prefs.getDouble('pet_happiness_decay_rate');
    
    _game.setStatRates(
      hungerDecayRate: hungerRate,
      happinessGainRate: happinessGain,
      happinessDecayRate: happinessDecay,
    );
  }

  Future<void> _saveStats() async {
    try {
      await _game.savePetStats();
    } catch (e) {
      print('Error saving pet stats: $e');
    }
  }

  Future<void> _restoreStats() async {
    try {
      await _game.loadPetStats(isDeviceSynced: _isDeviceSynced);
    } catch (e) {
      print('Error restoring pet stats: $e');
    }
  }

  void _listenToSyncStatus() {
    // Listen for native connection status updates
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'onConnectionStatusChanged') {
        final connected = call.arguments as bool? ?? false;
        setState(() {
          _isDeviceSynced = connected;
        });
        _game.setSyncStatus(_isDeviceSynced);
      }
    });
  }

  void _openDevTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DevToolsSettings(
        game: _game,
        onSyncStatusChanged: (synced) {
          setState(() {
            _isDeviceSynced = synced;
          });
          _game.setSyncStatus(synced);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: The Flame game (background)
          GameWidget(game: _game),
          
          // Layer 2: HUD overlay (foreground)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xE6FFFFFF),
                    shape: BoxShape.circle,
                    border: Border.all(width: 2, color: Colors.black),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.black),
                    onPressed: _openDevTools,
                    tooltip: 'Dev Tools',
                  ),
                ),
              ),
            ),
          ),
          
          // Layer 3: Sync status indicator (top-left)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xE6FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(width: 2, color: Colors.black),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isDeviceSynced ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isDeviceSynced ? 'SYNCED' : 'NOT SYNCED',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'Monocraft',
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
