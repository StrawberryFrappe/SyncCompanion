import 'package:flutter/material.dart';

class CurrencyDisplay extends StatelessWidget {
  final int gold;
  final int silver;

  const CurrencyDisplay({
    super.key,
    required this.gold,
    required this.silver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildCurrencyPill('GOLD', gold, Colors.amber),
        const SizedBox(height: 4),
        _buildCurrencyPill('SILVER', silver, Colors.blueGrey.shade200),
      ],
    );
  }

  Widget _buildCurrencyPill(String label, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 2, color: Colors.black),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(width: 1, color: Colors.black),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$amount',
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'Monocraft', // Assuming this font is used elsewhere
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
