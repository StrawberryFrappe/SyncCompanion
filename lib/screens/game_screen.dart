import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/virtual_pet_game.dart';
import '../services/pet_notification_service.dart';
import 'dev_tools_settings.dart';
import 'widgets/stat_indicator.dart';
import 'widgets/currency_display.dart';
import '../game/items/food_item.dart';
import 'widgets/food_menu.dart'; // Is now FoodStore inside
import 'widgets/wardrobe_menu.dart';
import 'widgets/fridge_widget.dart';

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
  // For UI updates
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = VirtualPetGame();
    _initializeGame();
    _listenToSyncStatus();
    
    // Auto-save stats every 15 seconds while app is active
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _saveStats();
    });

    // Update UI every second to reflect stat changes
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
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
    final lowWellbeingThreshold = prefs.getDouble('pet_low_wellbeing_threshold') ?? 0.25;
    
    _game.setStatRates(
      hungerDecayRate: hungerRate,
      happinessGainRate: happinessGain,
      happinessDecayRate: happinessDecay,
    );
    
    // Set up low wellbeing notification
    await _game.initialized;
    _game.currentPet.stats.lowWellbeingThreshold = lowWellbeingThreshold;
    _game.currentPet.stats.onLowWellbeing = () {
      PetNotificationService().showLowWellbeingNotification();
    };
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
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: DevToolsSettings(
          game: _game,
          onSyncStatusChanged: (synced) {
            setState(() {
              _isDeviceSynced = synced;
            });
            _game.setSyncStatus(synced);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current stats
    final stats = _game.getStatValues();
    final hunger = stats['hunger'] ?? 0.0;
    final happiness = stats['happiness'] ?? 0.0;

    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: The Flame game (background) with DragTarget
          Positioned.fill(
            child: DragTarget<FoodItem>(
              onWillAccept: (data) => true,
              onAccept: (item) {
                // Guard against accessing pet before initialized
                if (!_game.isReady) return;
                // Determine if successful
                if (_game.currentPet.stats.removeFood(item.id)) {
                  _game.currentPet.eat(item);
                  _saveStats();
                  setState(() {}); // Update Fridge UI
                }
              },
              builder: (context, candidates, rejects) {
                // Visual feedback when dragging food over the game area
                if (candidates.isNotEmpty) {
                  return Container(
                    color: Colors.green.withOpacity(0.1),
                    child: GameWidget(game: _game),
                  );
                }
                return GameWidget(game: _game);
              },
            ),
          ),
          
          // Layer 2: Main HUD (Top Center)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Happiness (Hearts)
                    StatIndicator(
                      value: happiness,
                      assetPath: 'assets/images/ui_heart.png',
                      totalIcons: 5,
                      iconSize: 28,
                    ),
                    const SizedBox(height: 4),
                    // Hunger (Drumsticks)
                    StatIndicator(
                      value: hunger,
                      assetPath: 'assets/images/ui_hunger.png',
                      totalIcons: 5,
                      iconSize: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Layer 3: HUD overlay (foreground) - Settings & Currency
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
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
                    const SizedBox(height: 8),
                    CurrencyDisplay(
                      gold: stats['gold']?.toInt() ?? 0,
                      silver: stats['silver']?.toInt() ?? 0,
                    ),
                  ],
                ),
              ),
            ),
          ),

          

          // Layer 4: Sync status indicator (top-left)
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

          // Layer 6: Fridge (Bottom Center)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 0, left: 100, right: 100),
                child: FridgeWidget(
                  inventory: _game.getFoodInventory(),
                ),
              ),
            ),
          ),

          // Layer 5: Food Shop Button (Bottom Right)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: FloatingActionButton(
                    heroTag: 'food_btn',
                    backgroundColor: Colors.orange.shade300,
                    shape: CircleBorder(side: BorderSide(width: 2, color: Colors.black)),
                    onPressed: _openFoodStore,
                    child: const Icon(Icons.store, color: Colors.black, size: 32),
                  ),
                ),
              ),
            ),
          ),

          // Layer 6: Wardrobe Button (Bottom Left)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: FloatingActionButton(
                    heroTag: 'clothing_btn',
                    backgroundColor: Colors.purple.shade200,
                    shape: CircleBorder(side: BorderSide(width: 2, color: Colors.black)),
                    onPressed: _openWardrobeMenu,
                    child: const Icon(Icons.checkroom, color: Colors.black, size: 32),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFoodStore() {
    if (!_game.isReady) return;
    showDialog(
      context: context,
      builder: (context) => FoodStore(
        currentSilver: _game.currentPet.stats.silverCoins,
        onBuy: (item) {
          // Check affordability
          if (_game.currentPet.stats.spendSilver(item.cost)) {
             // Add to inventory instead of feeding immediately
             _game.currentPet.stats.addFood(item.id, 1);
             _saveStats(); // Save immediately
             setState(() {}); // Update UI to show new silver
          }
        },
      ),
    ).then((_) => setState(() {})); // Refresh when closing loop
  }

  void _openWardrobeMenu() {
    if (!_game.isReady) return;
    showDialog(
      context: context,
      builder: (context) => WardrobeMenuWidget(
        stats: _game.currentPet.stats,
        onBuy: (item) {
          if (_game.currentPet.stats.spendGold(item.cost)) {
            _game.currentPet.stats.unlockClothing(item.id);
            _saveStats();
            setState(() {});
          }
        },
        onEquip: (item) {
          _game.currentPet.stats.equipClothing(item.slot.name, item.id);
          _game.currentPet.updateEquipment();
          _saveStats();
          setState(() {});
        },
        onUnequip: (item) {
          _game.currentPet.stats.unequipClothing(item.slot.name);
          _game.currentPet.updateEquipment();
          _saveStats();
          setState(() {});
        },
      ),
    ).then((_) {
      setState(() {});
      _game.currentPet.updateEquipment(); // Ensure synced
    });
  }
}
