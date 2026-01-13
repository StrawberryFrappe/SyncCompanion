import 'package:flutter/material.dart';
import '../widgets/settings_inputs.dart';

/// Flappy Bob game settings section.
class FlappyGameSection extends StatelessWidget {
  final double coinMultiplier;
  final ValueChanged<double> onMultiplierChanged;

  const FlappyGameSection({
    super.key,
    required this.coinMultiplier,
    required this.onMultiplierChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(width: 2, color: Colors.black),
        color: Colors.cyan.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FLAPPY BOB GAME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FloatInput(
            label: 'Coin Multiplier',
            subtitle: 'Silver = Score * Multiplier',
            currentValue: coinMultiplier,
            onApply: onMultiplierChanged,
            backgroundColor: Colors.cyan.shade100,
          ),
          const SizedBox(height: 4),
          Text(
            'Score 10 = ${(10 * coinMultiplier).toInt()} silver coins',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
