import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../screens/minigame_screen.dart';
import '../../../services/device/device_service.dart';
import '../../pets/pet_stats.dart';
import 'orchestra_game.dart';

/// Screen wrapper for the Orchestra minigame.
class OrchestraScreen extends StatefulWidget {
  final DeviceService deviceService;
  final PetStats petStats;
  final bool isDeviceConnected;

  const OrchestraScreen({
    super.key,
    required this.deviceService,
    required this.petStats,
    this.isDeviceConnected = false,
  });

  @override
  State<OrchestraScreen> createState() => _OrchestraScreenState();
}

class _OrchestraScreenState extends State<OrchestraScreen> {
  late final OrchestraGame _game;

  @override
  void initState() {
    super.initState();
    
    _game = OrchestraGame(
      deviceService: widget.deviceService,
      petStats: widget.petStats,
      isDeviceConnected: widget.isDeviceConnected,
      onExit: () {
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MinigameScreen(
      config: const MinigameConfig(
        title: 'Pet Orchestra',
        keepScreenOn: true,
        forcedOrientations: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      ),
      gameWidget: GameWidget(game: _game),
      onDispose: () {
        // Force cleanup of game audio before disposing
        _game.cleanup();
      },
    );
  }
}
