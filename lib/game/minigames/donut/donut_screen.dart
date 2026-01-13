import 'package:flutter/material.dart';

import '../../../screens/minigame_screen.dart';
import '../../../services/device/device_service.dart';
import 'donut.dart';

/// Screen wrapper for the Donut minigame.
class DonutScreen extends StatelessWidget {
  final DeviceService deviceService;

  const DonutScreen({
    super.key,
    required this.deviceService,
  });

  @override
  Widget build(BuildContext context) {
    return MinigameScreen(
      config: const MinigameConfig(
        title: 'Spinning Donut',
        keepScreenOn: true,
        showAppBar: true,
      ),
      gameWidget: DonutGame(deviceService: deviceService),
    );
  }
}
