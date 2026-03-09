import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screens/minigame_screen.dart';
import '../../../services/device/device_service.dart';
import '../../pets/pet_stats.dart';
import 'flappy_bird_game.dart';
import 'flappy_difficulty.dart';

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
  FlappyDifficulty _selectedDifficulty = FlappyDifficulty.medium;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _jumpThreshold = prefs.getDouble('flappy_jump_threshold') ?? 1.5;
      final savedDifficulty = prefs.getString('flappy_difficulty') ?? 'medium';
      _selectedDifficulty = FlappyDifficulty.values.firstWhere(
        (d) => d.name == savedDifficulty,
        orElse: () => FlappyDifficulty.medium,
      );
    });
  }
  
  Future<void> _saveThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('flappy_jump_threshold', value);
  }

  Future<void> _saveDifficulty(FlappyDifficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flappy_difficulty', difficulty.name);
  }

  FlappyDifficultyConfig get _config =>
      FlappyDifficultyConfig.presets[_selectedDifficulty]!;

  void _startGame() {
    setState(() {
      _showTitleScreen = false;
      _game = FlappyBirdGame(
        deviceService: widget.deviceService,
        petStats: widget.petStats,
        isDeviceConnected: widget.isDeviceConnected,
        jumpThreshold: _jumpThreshold,
        difficultyConfig: _config,
        onGameOver: _onGameOver,
      );
    });
  }
  
  void _onGameOver() {
    final score = _game?.score ?? 0;
    final coins = (score * _config.coinMultiplier).toInt();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(width: 4, color: Colors.black),
        ),
        title: Text(
          AppLocalizations.of(context)!.gameOver,
          style: TextStyle(fontFamily: 'Monocraft', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(
              AppLocalizations.of(context)!.scoreLabel(score),
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
                    Text(AppLocalizations.of(context)!.silverReward(coins), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            child: Text(AppLocalizations.of(context)!.retry),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Exit game
            },
            child: Text(AppLocalizations.of(context)!.exit),
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
  
  String _difficultyLabel(FlappyDifficulty d) {
    final l10n = AppLocalizations.of(context)!;
    switch (d) {
      case FlappyDifficulty.easy:
        return l10n.difficultyEasy;
      case FlappyDifficulty.medium:
        return l10n.difficultyMedium;
      case FlappyDifficulty.hard:
        return l10n.difficultyHard;
      case FlappyDifficulty.extreme:
        return l10n.difficultyExtreme;
    }
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
              Text(
                AppLocalizations.of(context)!.flappyBobTitle,
                style: TextStyle(
                  fontFamily: 'Monocraft',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isDeviceConnected 
                    ? AppLocalizations.of(context)!.shakeToFlap
                    : AppLocalizations.of(context)!.tapToFlap,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDeviceConnected ? Colors.green : Colors.orange,
                ),
              ),
              if (!widget.isDeviceConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    AppLocalizations.of(context)!.foodSpriteHint,
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              
              const SizedBox(height: 20),

              // Difficulty selector
              Text(
                AppLocalizations.of(context)!.difficultyLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<FlappyDifficulty>(
                segments: FlappyDifficulty.values.map((d) => ButtonSegment<FlappyDifficulty>(
                  value: d,
                  label: Text(
                    _difficultyLabel(d),
                    style: const TextStyle(fontSize: 11),
                  ),
                )).toList(),
                selected: {_selectedDifficulty},
                onSelectionChanged: (selection) {
                  setState(() => _selectedDifficulty = selection.first);
                  _saveDifficulty(selection.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              const SizedBox(height: 16),
              
              // Jump threshold slider (only when connected)
              if (widget.isDeviceConnected) ...[
                Text(AppLocalizations.of(context)!.jumpSensitivity, style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(AppLocalizations.of(context)!.high),
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
                    Text(AppLocalizations.of(context)!.low),
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
                child: Text(
                  AppLocalizations.of(context)!.start,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.back),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
