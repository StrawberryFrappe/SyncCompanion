import 'package:flutter/material.dart';
import '../widgets/settings_inputs.dart';

/// Notifications settings section.
class NotificationsSection extends StatelessWidget {
  final double lowWellbeingThreshold;
  final ValueChanged<double> onThresholdChanged;

  const NotificationsSection({
    super.key,
    required this.lowWellbeingThreshold,
    required this.onThresholdChanged,
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
          const Text('NOTIFICATIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ThresholdInput(
            label: 'Low Wellbeing Alert Threshold',
            currentThreshold: lowWellbeingThreshold,
            onApply: onThresholdChanged,
          ),
          const SizedBox(height: 4),
          Text(
            'Notify when wellbeing drops to ${(lowWellbeingThreshold * 100).toStringAsFixed(0)}% or below',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
