import 'package:flutter/material.dart';

/// StatIndicator - Displays a value (0.0 - 1.0) as a row of retro icons.
/// Example: 5 hearts for happiness.
class StatIndicator extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final String assetPath;
  final int totalIcons;
  final double iconSize;

  const StatIndicator({
    super.key,
    required this.value,
    required this.assetPath,
    this.totalIcons = 5,
    this.iconSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    // Determine how many full icons to show
    // e.g. 0.7 * 5 = 3.5 -> 3 full, 1 half (if supported), or just round
    // For simplicity/retro feel, we can just dim the inactive ones
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalIcons, (index) {
        // Value for this specific icon slot (e.g. 0.2, 0.4, 0.6...)
        final slotThreshold = (index + 1) / totalIcons;
        final isActive = value >= slotThreshold - (0.5 / totalIcons); 
        // Logic: if value is 0.9, and we have 5 icons:
        // 1: 0.2 (active)
        // 2: 0.4 (active)
        // 3: 0.6 (active)
        // 4: 0.8 (active)
        // 5: 1.0 (inactive? 0.9 is < 1.0)
        // Let's make it proportional.
        
        // Better logic: each icon represents 1/totalIcons of the bar.
        // If current value covers this icon's portion, it's full.
        final iconValue = (value * totalIcons) - index;
        
        double opacity = 0.3; // Default empty
        if (iconValue >= 1.0) {
          opacity = 1.0; // Full
        } else if (iconValue > 0.0) {
           opacity = 0.3 + (0.7 * iconValue); // Partial fade? Or just keep it solid for retro style?
           // Retro style usually does whole units or half units. 
           // Let's stick to simple threshold: if > 50% of this unit, it's lit.
           opacity = iconValue >= 0.5 ? 1.0 : 0.3;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Opacity(
            opacity: opacity,
            child: Image.asset(
              assetPath,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none, // Keep pixel art crisp
            ),
          ),
        );
      }),
    );
  }
}
