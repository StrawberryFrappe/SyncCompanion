import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/virtual_pet_game.dart';
import '../services/device/device_service.dart';
import '../services/notifications/pet_notification_service.dart';
import '../services/cloud/cloud_service.dart';
import '../game/missions/mission_service.dart';
import '../game/missions/mission.dart';

import 'settings/dev_tools_settings.dart';
import 'widgets/hud/game_hud.dart';
import '../game/minigames/flappy_bird/flappy_bird_screen.dart';
import '../game/minigames/orchestra/orchestra_screen.dart';
import '../game/minigames/donut/donut_screen.dart';
import '../game/minigames/sbr/sbr_screen.dart';

import '../game/items/food_item.dart';
import 'widgets/menus/food_menu.dart'; // Is now FoodStore inside
import 'widgets/menus/game_menu.dart';
import 'widgets/menus/wardrobe_menu.dart';
import 'widgets/menus/fridge_widget.dart';

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
  late final DeviceService _deviceService;
  
  DeviceDisplayStatus _connectionStatus = DeviceDisplayStatus.searching;
  StreamSubscription<dynamic>? _syncSub;
  
  bool _showFridge = false; // Toggle for fridge visibility
  
  // For periodic stat saving while app is active
  Timer? _autoSaveTimer;
  // For UI updates
  Timer? _uiUpdateTimer;
  
  // For background usage tracking
  bool _isPaused = false;
  int _backgroundSyncSeconds = 0;
  DateTime? _backgroundSyncStartTime;
  Timer? _backgroundTicker;
  
  // Group ID for Fridge TapRegion to allow button clicks to be ignored
  final _fridgeGroupId = Object();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = VirtualPetGame();
    _deviceService = DeviceService();
    _deviceService.init();
    _initializeGame();
    _listenToSyncStatus();
    
    // Auto-save stats every 15 seconds while app is active
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _saveStats();
    });

    // Update UI every second to reflect stat changes and mission progress
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        MissionService().update(MissionContext(
          dt: 1.0,
          isDeviceSynced: _connectionStatus == DeviceDisplayStatus.synced,
        ));
        setState(() {});
      }
    });

    // Accurate background tracking ticker
    _backgroundTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused && _game.isReady) {
        final isSynced = _connectionStatus == DeviceDisplayStatus.synced;
        
        // Advance the math live manually while UI/Flame is frozen
        _game.currentPet.stats.update(1.0, isDeviceSynced: isSynced);
        
        if (isSynced) {
          if (_backgroundSyncSeconds == 0) {
            _backgroundSyncStartTime = DateTime.now();
          }
          _backgroundSyncSeconds++;
        } else {
          if (_backgroundSyncSeconds > 0) {
            CloudService().logSyncSession(
              duration: Duration(seconds: _backgroundSyncSeconds),
              startTime: _backgroundSyncStartTime!,
            );
            _backgroundSyncSeconds = 0;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _backgroundTicker?.cancel();
    _uiUpdateTimer?.cancel();
    _autoSaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _syncSub?.cancel();
    unawaited(_saveStats()); // Save on dispose
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('[GameScreen] Lifecycle state changed: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
        _isPaused = true;
        // App fully backgrounded - save current state with timestamp.
        // NOTE: Only save on 'paused', not 'inactive'/'hidden' which also fire when RETURNING.
        // didChangeAppLifecycleState returns void so we can't await — fire-and-forget is intentional.
        print('[GameScreen] Saving stats (app paused/backgrounded)');
        unawaited(_saveStats());
        break;
      case AppLifecycleState.resumed:
        _isPaused = false;
        // Push any remaining tracked session immediately
        if (_backgroundSyncSeconds > 0) {
          CloudService().logSyncSession(
            duration: Duration(seconds: _backgroundSyncSeconds),
            startTime: _backgroundSyncStartTime!,
          );
          _backgroundSyncSeconds = 0;
        }
        // Re-attach native event bridge and reset stale Dart state
        _deviceService.onAppResumed();
        // App returning to foreground - restore and apply background updates
        print('[GameScreen] Restoring stats (returning to foreground)');
        _restoreStats();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // These states fire both when leaving AND when returning to the
        // foreground — don't save here to avoid redundant writes.
        print('[GameScreen] Lifecycle transition state: $state (no action)');
        break;
      case AppLifecycleState.detached:
        // Fired only when the app is being destroyed (e.g. swiped from recents
        // while in the foreground).  This is the last chance to flush data
        // before the process is killed, so save everything.
        // didChangeAppLifecycleState returns void so we can't await — fire-and-forget is intentional.
        print('[GameScreen] Saving stats (app detached/being destroyed)');
        unawaited(_saveStats());
        break;
    }
  }

  Future<void> _initializeGame() async {
    await _loadSyncStatus();
    await _loadPersistedRates();
    await _restoreStats();

    // Initialize mission service once pet stats are ready
    await _game.initialized;
    await MissionService().init(_game.currentPet.stats);
  }

  Future<void> _loadSyncStatus() async {
    // Initial status load
    setState(() {
      _connectionStatus = _deviceService.currentDisplayStatus;
    });
    _game.setSyncStatus(_connectionStatus == DeviceDisplayStatus.synced);
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
    try {
      await MissionService().save();
    } catch (e) {
      print('Error saving missions: $e');
    }
  }

  Future<void> _restoreStats() async {
    try {
      // Offline/killed recovery: if the OS completely suspended or killed the app,
      // the background ticker couldn't run. Because the BLE radio connection drops 
      // when the app is suspended/killed, the device could not possibly be "synced".
      // Therefore, we jump the missing time defaulting to `false`.
      await _game.loadPetStats(isDeviceSynced: false);
    } catch (e) {
      print('Error restoring pet stats: $e');
    }
  }

  void _listenToSyncStatus() {
    // Listen for high-level display status updates from DeviceService
    _syncSub = _deviceService.displayStatus$.listen((status) {
      setState(() {
        _connectionStatus = status;
      });
      _game.setSyncStatus(status == DeviceDisplayStatus.synced);
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
              _connectionStatus = synced ? DeviceDisplayStatus.synced : DeviceDisplayStatus.searching;
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
    
    // Adaptive sizing
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 380;
    final double buttonSize = isSmallScreen ? 48.0 : 64.0;
    final double iconSize = isSmallScreen ? 24.0 : 32.0;
    final double padding = 16.0;

    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: The Flame game (background) with DragTarget
          Positioned.fill(
            child: DragTarget<FoodItem>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) {
                final item = details.data;
                // Guard against accessing pet before initialized
                if (!_game.isReady) return;
                // Determine if successful
                if (_game.currentPet.stats.removeFood(item.id)) {
                  _game.currentPet.eat(item);
                  MissionService().update(MissionContext(foodId: item.id));
                  _saveStats();
                  setState(() {}); // Update Fridge UI
                }
              },
              builder: (context, candidates, rejects) {
                // Visual feedback when dragging food over the game area
                if (candidates.isNotEmpty) {
                  return Container(
                    color: Colors.green.withAlpha(25),
                    child: GameWidget(game: _game),
                  );
                }
                return GameWidget(game: _game);
              },
            ),
          ),
          
          // Layer 2: Main HUD
          GameHud(
            hunger: hunger,
            happiness: happiness,
            gold: stats['gold']?.toInt() ?? 0,
            silver: stats['silver']?.toInt() ?? 0,
            connectionStatus: _connectionStatus,
            onSettingsPressed: _openDevTools,
          ),

          // Layer 6: Fridge (Animated Sidebar Right)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _showFridge ? 0 : -150,
            top: 100,
            bottom: 100,
            child: SafeArea( 
              child: Center(
                child: TapRegion(
                  groupId: _fridgeGroupId,
                  onTapOutside: (_) {
                    if (_showFridge) {
                      setState(() {
                        _showFridge = false;
                      });
                    }
                  },
                  child: FridgeWidget(
                    inventory: _game.getFoodInventory(),
                  ),
                ),
              ),
            ),
          ),

          // Layer 5: Food Shop Button & Fridge Toggle (Bottom Right)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fridge Toggle Button
                    SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: TapRegion(
                        groupId: _fridgeGroupId,
                        child: FloatingActionButton(
                          heroTag: 'fridge_btn',
                          backgroundColor: Colors.blue.shade200,
                          shape: const CircleBorder(side: BorderSide(width: 2, color: Colors.black)),
                          onPressed: () {
                            setState(() {
                              _showFridge = !_showFridge;
                            });
                          },
                          child: Icon(Icons.kitchen, color: Colors.black, size: iconSize),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Food Store Button
                    SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: FloatingActionButton(
                        heroTag: 'food_btn',
                        backgroundColor: Colors.orange.shade300,
                        shape: const CircleBorder(side: BorderSide(width: 2, color: Colors.black)),
                        onPressed: _openFoodStore,
                        child: Icon(Icons.store, color: Colors.black, size: iconSize),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Layer 6: Wardrobe + Games Buttons (Bottom Left)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Games Button
                    SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: FloatingActionButton(
                        heroTag: 'games_btn',
                        backgroundColor: Colors.cyan.shade200,
                        shape: const CircleBorder(side: BorderSide(width: 2, color: Colors.black)),
                        onPressed: _openGameMenu,
                        child: Icon(Icons.sports_esports, color: Colors.black, size: iconSize),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Wardrobe Button
                    SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: FloatingActionButton(
                        heroTag: 'clothing_btn',
                        backgroundColor: Colors.purple.shade200,
                        shape: const CircleBorder(side: BorderSide(width: 2, color: Colors.black)),
                        onPressed: _openWardrobeMenu,
                        child: Icon(Icons.checkroom, color: Colors.black, size: iconSize),
                      ),
                    ),
                  ],
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return FoodStore(
            // Since we're inside StatefulBuilder, accessing stats here ensures we get the *current* value on rebuild
            currentSilver: _game.currentPet.stats.silverCoins,
            onBuy: (item) {
              // Check affordability
              if (_game.currentPet.stats.spendSilver(item.cost)) {
                 // Add to inventory instead of feeding immediately
                 _game.currentPet.stats.addFood(item.id, 1);
                 _saveStats(); // Save immediately
                 setState(() {}); // Update GameScreen UI (background)
                 setDialogState(() {}); // Update visual silver count in dialog
              }
            },
          );
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
  
  void _openGameMenu() {
    showDialog(
      context: context,
      builder: (context) => GameMenu(
        onClose: () => Navigator.of(context).pop(),
        onPlay: (gameId) {
          Navigator.of(context).pop(); // Close menu
          if (gameId == 'flappy_bird') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FlappyBirdScreen(
                  deviceService: _deviceService,
                  petStats: _game.currentPet.stats,
                  isDeviceConnected: _connectionStatus == DeviceDisplayStatus.synced || _connectionStatus == DeviceDisplayStatus.connected,
                ),
              ),
            ).then((_) {
              MissionService().update(MissionContext(minigameId: 'flappy_bird'));
              // Refresh stats after returning from game
              _saveStats();
              setState(() {});
            });
          } else if (gameId == 'orchestra') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrchestraScreen(
                  deviceService: _deviceService,
                  petStats: _game.currentPet.stats,
                  isDeviceConnected: _connectionStatus == DeviceDisplayStatus.synced || _connectionStatus == DeviceDisplayStatus.connected,
                ),
              ),
            ).then((_) {
              MissionService().update(MissionContext(minigameId: 'orchestra'));
              setState(() {});
            });
          } else if (gameId == 'donut') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DonutScreen(
                  deviceService: _deviceService,
                ),
              ),
            ).then((_) {
              MissionService().update(MissionContext(minigameId: 'donut'));
            });
          } else if (gameId == 'sbr') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SBRScreen(
                  deviceService: _deviceService,
                  petStats: _game.currentPet.stats,
                  isDeviceConnected: _connectionStatus == DeviceDisplayStatus.synced || _connectionStatus == DeviceDisplayStatus.connected,
                  onGameOver: () => Navigator.of(context).pop(),
                ),
              ),
            ).then((_) {
              MissionService().update(MissionContext(minigameId: 'sbr'));
              // Refresh stats
              _saveStats();
              setState(() {});
            });
          }
        },
      ),
    );
  }
}
