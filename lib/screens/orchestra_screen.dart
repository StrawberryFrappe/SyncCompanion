import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/minigames/orchestra/orchestra_game.dart';
import '../game/pets/pet_stats.dart';
import '../services/bluetooth_service.dart';

/// Screen wrapper for the Orchestra minigame.
class OrchestraScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final PetStats petStats;
  final bool isDeviceConnected;

  const OrchestraScreen({
    super.key,
    required this.bluetoothService,
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
      bluetoothService: widget.bluetoothService,
      petStats: widget.petStats,
      isDeviceConnected: widget.isDeviceConnected,
      onExit: () {
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(game: _game),
    );
  }
}
