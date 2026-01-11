import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/minigames/orchestra/orchestra_game.dart';
import '../game/pets/pet_stats.dart';
import '../../services/device_service.dart';

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
    
    // Force landscape orientation for the orchestra game
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
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
  void dispose() {
    // Force cleanup of game audio before disposing
    _game.cleanup();
    
    // Restore all orientations when leaving the orchestra screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(game: _game),
    );
  }
}
