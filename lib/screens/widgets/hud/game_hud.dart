import 'package:flutter/material.dart';
import '../../../services/device/device_service.dart';
import 'currency_display.dart';
import 'mission_overlay.dart';
import 'stat_indicator.dart';

class GameHud extends StatelessWidget {
  final double hunger;
  final double happiness;
  final int gold;
  final int silver;
  final DeviceDisplayStatus connectionStatus;
  final VoidCallback onSettingsPressed;

  const GameHud({
    super.key,
    required this.hunger,
    required this.happiness,
    required this.gold,
    required this.silver,
    required this.connectionStatus,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status UI properties
    Color statusColor;
    String statusText;

    switch (connectionStatus) {
      case DeviceDisplayStatus.synced:
        statusColor = Colors.green;
        statusText = 'SYNCED';
        break;
      case DeviceDisplayStatus.waiting:
        statusColor = Colors.amber;
        statusText = 'WAITING';
        break;
      case DeviceDisplayStatus.searching:
      default:
        statusColor = Colors.red;
        statusText = 'SEARCHING';
        break;
    }

    return Stack(
      children: [
        // Layer 2: Main HUD (Top Center)
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Happiness (Hearts)
                  StatIndicator(
                    value: happiness,
                    assetPath: 'assets/images/ui_heart.png',
                    totalIcons: 5,
                    iconSize: 28,
                  ),
                  const SizedBox(height: 4),
                  // Hunger (Drumsticks)
                  StatIndicator(
                    value: hunger,
                    assetPath: 'assets/images/ui_hunger.png',
                    totalIcons: 5,
                    iconSize: 28,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Layer 3: HUD overlay (foreground) - Settings & Currency
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xE6FFFFFF),
                      shape: BoxShape.circle,
                      border: Border.all(width: 2, color: Colors.black),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.black),
                      onPressed: onSettingsPressed,
                      tooltip: 'Dev Tools',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const MissionOverlay(),
                ],
              ),
            ),
          ),
        ),

        // Layer 4: Status & Currency (Top Left)
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xE6FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(width: 2, color: Colors.black),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'Monocraft',
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CurrencyDisplay(
                    gold: gold,
                    silver: silver,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
