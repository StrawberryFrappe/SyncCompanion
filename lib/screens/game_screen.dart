import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/virtual_pet_game.dart';
import '../services/device/device_service.dart';
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
import 'widgets/menus/fridge_widget.dart';
import 'widgets/menus/wardrobe_menu.dart';
import 'controllers/game_screen_controller.dart';

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
  late final GameScreenController _controller;
  
  bool _showFridge = false; 
  final _fridgeGroupId = Object();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = VirtualPetGame();
    _deviceService = DeviceService();
    _deviceService.init();
    
    _controller = GameScreenController(game: _game, deviceService: _deviceService);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _controller.handleLifecycleChange(state);
  }



  Future<void> _saveStats() async {
    await _controller.saveStats();
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
            _game.setSyncStatus(synced);
            setState(() {});
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
              connectionStatus: _controller.connectionStatus,
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
                  isDeviceConnected: _controller.connectionStatus == DeviceDisplayStatus.synced || _controller.connectionStatus == DeviceDisplayStatus.connected,
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
                  isDeviceConnected: _controller.connectionStatus == DeviceDisplayStatus.synced || _controller.connectionStatus == DeviceDisplayStatus.connected,
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
                  isDeviceConnected: _controller.connectionStatus == DeviceDisplayStatus.synced || _controller.connectionStatus == DeviceDisplayStatus.connected,
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
