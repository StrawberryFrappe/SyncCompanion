import 'package:flutter/material.dart';
import '../widgets/settings_inputs.dart';

/// Stat Rates settings section.
class StatRatesSection extends StatelessWidget {
  final double hungerDecayRate;
  final double happinessGainRate;
  final double happinessDecayRate;
  final ValueChanged<double> onHungerDecayChanged;
  final ValueChanged<double> onHappinessGainChanged;
  final ValueChanged<double> onHappinessDecayChanged;

  const StatRatesSection({
    super.key,
    required this.hungerDecayRate,
    required this.happinessGainRate,
    required this.happinessDecayRate,
    required this.onHungerDecayChanged,
    required this.onHappinessGainChanged,
    required this.onHappinessDecayChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(width: 2, color: Colors.black),
        color: const Color(0xFFF5F5F5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('STAT RATES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('(${(hungerDecayRate * 100).toStringAsFixed(3)}%/s, ${(happinessGainRate * 100).toStringAsFixed(3)}%/s, ${(happinessDecayRate * 100).toStringAsFixed(3)}%/s)', 
                style: const TextStyle(fontSize: 8, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          RateInput(
            label: 'Hunger Decay',
            currentRate: hungerDecayRate,
            onApply: onHungerDecayChanged,
          ),
          const SizedBox(height: 8),
          RateInput(
            label: 'Happiness Gain (synced)',
            currentRate: happinessGainRate,
            onApply: onHappinessGainChanged,
          ),
          const SizedBox(height: 8),
          RateInput(
            label: 'Happiness Decay (not synced)',
            currentRate: happinessDecayRate,
            onApply: onHappinessDecayChanged,
          ),
        ],
      ),
    );
  }
}
