import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screens/minigame_screen.dart';
import '../../../services/device/device_service.dart';
import '../../pets/pet_stats.dart';
import 'flappy_bird_game.dart';

/// Screen that hosts the Flappy Bird game with title overlay and game over dialog.
class FlappyBirdScreen extends StatefulWidget {
  final DeviceService deviceService;
  final PetStats petStats;
  final bool isDeviceConnected;

  const FlappyBirdScreen({
    super.key,
    required this.deviceService,
    required this.petStats,
    required this.isDeviceConnected,
  });

  @override
  State<FlappyBirdScreen> createState() => _FlappyBirdScreenState();
}

class _FlappyBirdScreenState extends State<FlappyBirdScreen> {
  FlappyBirdGame? _game;
  bool _showTitleScreen = true;
  double _jumpThreshold = 1.5;
  double _coinMultiplier = 1.0;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _jumpThreshold = prefs.getDouble('flappy_jump_threshold') ?? 1.5;
      _coinMultiplier = prefs.getDouble('flappy_coin_multiplier') ?? 1.0;
    });
  }
  
  Future<void> _saveThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('flappy_jump_threshold', value);
  }

  void _startGame() {
    setState(() {
      _showTitleScreen = false;
      _game = FlappyBirdGame(
        deviceService: widget.deviceService,
        petStats: widget.petStats,
        isDeviceConnected: widget.isDeviceConnected,
        jumpThreshold: _jumpThreshold,
        coinRewardMultiplier: _coinMultiplier,
        onGameOver: _onGameOver,
      );
    });
  }
  
  void _onGameOver() {
    final score = _game?.score ?? 0;
    final coins = (score * _coinMultiplier).toInt();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(width: 4, color: Colors.black),
        ),
        title: const Text(
          'GAME OVER',
          style: TextStyle(fontFamily: 'Monocraft', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Score: $score',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (coins > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('+$coins Silver', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _startGame(); // Restart
            },
            child: const Text('RETRY'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Exit game
            },
            child: const Text('EXIT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MinigameScreen(
      config: const MinigameConfig(
        title: 'Flappy Bob',
        keepScreenOn: true,
      ),
      gameWidget: _game != null
          ? GameWidget(game: _game!)
          : Container(color: const Color(0xFF87CEEB)),
      overlay: _showTitleScreen ? _buildTitleScreen() : null,
    );
  }
  
  Widget _buildTitleScreen() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(width: 4, color: Colors.black),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'FLAPPY BOB',
                style: TextStyle(
                  fontFamily: 'Monocraft',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isDeviceConnected 
                    ? 'Shake to flap!'
                    : 'Tap to flap (No device)',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDeviceConnected ? Colors.green : Colors.orange,
                ),
              ),
              if (!widget.isDeviceConnected)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '(You get a food sprite!)',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Jump threshold slider (only when connected)
              if (widget.isDeviceConnected) ...[
                const Text('Jump Sensitivity', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('High'),
                    Expanded(
                      child: Slider(
                        value: _jumpThreshold,
                        min: 1.1,
                        max: 2.5,
                        divisions: 14,
                        label: '${_jumpThreshold.toStringAsFixed(1)}g',
                        onChanged: (value) {
                          setState(() => _jumpThreshold = value);
                          _saveThreshold(value);
                        },
                      ),
                    ),
                    const Text('Low'),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              // Start button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  side: const BorderSide(width: 2, color: Colors.black),
                ),
                onPressed: _startGame,
                child: const Text(
                  'START',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
