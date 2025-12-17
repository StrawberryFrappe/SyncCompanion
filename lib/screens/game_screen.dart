import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/virtual_pet_game.dart';
import 'dev_tools_settings.dart';

/// GameScreen - The main screen of the app.
/// Uses a Stack to layer the Flame game underneath a minimal HUD overlay.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final VirtualPetGame _game;

  @override
  void initState() {
    super.initState();
    _game = VirtualPetGame();
  }

  void _openDevTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DevToolsSettings(),
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
                    color: Colors.white.withOpacity(0.9),
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
        ],
      ),
    );
  }
}
