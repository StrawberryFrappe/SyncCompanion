import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../services/device/device_service.dart';
import '../../pets/pet_stats.dart';

import 'calibration_overlay.dart';
import 'motion_calibrator.dart';
import 'sbr_game.dart';

class SBRScreen extends StatefulWidget {
  final DeviceService deviceService;
  final PetStats petStats;
  final bool isDeviceConnected;
  final VoidCallback onGameOver;
  
  const SBRScreen({
    super.key,
    required this.deviceService,
    required this.petStats,
    required this.isDeviceConnected,
    required this.onGameOver,
  });

  @override
  State<SBRScreen> createState() => _SBRScreenState();
}

class _SBRScreenState extends State<SBRScreen> {
  SBRGame? _game;
  bool _calibrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (_game == null) {
      _game = SBRGame(
        deviceService: widget.deviceService,
        petStats: widget.petStats,
        isDeviceConnected: widget.isDeviceConnected,
        onGameOver: widget.onGameOver,
        onStateChanged: () {
          Future.microtask(() {
            if (mounted) setState(() {});
          });
        },
      );

      // If no device connected, skip calibration
      if (!widget.isDeviceConnected) {
        _calibrated = true;
      }
    }
  }

  void _onCalibrationComplete(MotionCalibrator calibrator) {
    setState(() {
      _calibrated = true;
      _game!.calibrator = calibrator;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_game == null) return const Center(child: CircularProgressIndicator());

    // Show calibration overlay before the game if device is connected
    if (!_calibrated) {
      return CalibrationOverlay(
        deviceService: widget.deviceService,
        onCalibrationComplete: _onCalibrationComplete,
      );
    }
    
    return Stack(
      children: [
        // Game Engine
        GameWidget(game: _game!),
        
        // HUD Overlay
        Positioned(
          top: 40,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left HUD: Combo, Lives
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: ValueNotifier(_game!.combo), // Need to notify this properly, use stream or rebuild
                    builder: (context, combo, child) {
                      return Text('Combo: ${_game!.combo}', style: _hudStyle());
                    },
                  ),
                  Text('Level: ${_game!.currentLevel}', style: _hudStyle()),
                ],
              ),
              
              // Right HUD: Score
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Score: ${_game!.score}', style: _hudStyle()),
                  Text('Lives: ${_game!.lives}', style: _hudStyle(color: Colors.redAccent)),
                ],
              ),
            ],
          ),
        ),
        
        // Start Overlay
        if (!_game!.hasStarted && !_game!.isGameOver)
          Center(
            child: Text(
              'Tap to Start!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(offset: Offset(2, 2), blurRadius: 4)],
              ),
            ),
          ),
          
        // Game Over Overlay
        if (_game!.isGameOver)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GAME OVER',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(offset: Offset(2, 2), blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Score: ${_game!.score}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    shadows: [Shadow(offset: Offset(2, 2), blurRadius: 4)],
                  ),
                ),
              ],
            ),
          )
      ],
    );
  }
  
  TextStyle _hudStyle({Color color = Colors.white}) {
    return TextStyle(
      color: color,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black)],
    );
  }
}
