import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';

/// Section widget displaying pet stats with manipulation controls.
class PetStatsSection extends StatelessWidget {
  final double hunger;
  final double happiness;
  final double wellbeing;
  final VoidCallback? onAddGold;
  final VoidCallback? onAddSilver;

  const PetStatsSection({
    super.key,
    required this.hunger,
    required this.happiness,
    required this.wellbeing,
    this.onAddGold,
    this.onAddSilver,
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
          Text(AppLocalizations.of(context)!.petStats, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildStatBar(AppLocalizations.of(context)!.hunger, hunger, Colors.orange),
          const SizedBox(height: 4),
          _buildStatBar(AppLocalizations.of(context)!.happiness, happiness, Colors.pink),
          const SizedBox(height: 4),
          _buildStatBar(AppLocalizations.of(context)!.wellbeing, wellbeing, Colors.green),
          const SizedBox(height: 8),
          
          // Money Debug Controls
          Text(AppLocalizations.of(context)!.economyDebug, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade100,
                    foregroundColor: Colors.black,
                    side: const BorderSide(width: 1, color: Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onPressed: onAddGold,
                  child: Text(AppLocalizations.of(context)!.addGold, style: const TextStyle(fontSize: 9)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade100,
                    foregroundColor: Colors.black,
                    side: const BorderSide(width: 1, color: Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onPressed: onAddSilver,
                  child: Text(AppLocalizations.of(context)!.addSilver, style: const TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 10)),
        ),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(width: 1, color: Colors.black),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 35,
          child: Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
