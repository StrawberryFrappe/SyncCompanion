import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';
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
          Text(AppLocalizations.of(context)!.flappyBobGame, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FloatInput(
            label: AppLocalizations.of(context)!.coinMultiplier,
            subtitle: AppLocalizations.of(context)!.silverFormula,
            currentValue: coinMultiplier,
            onApply: onMultiplierChanged,
            backgroundColor: Colors.cyan.shade100,
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.scoreExample((10 * coinMultiplier).toInt()),
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
