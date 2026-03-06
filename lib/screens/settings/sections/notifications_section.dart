import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';
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
          Text(AppLocalizations.of(context)!.notifications, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ThresholdInput(
            label: AppLocalizations.of(context)!.lowWellbeingAlertThreshold,
            currentThreshold: lowWellbeingThreshold,
            onApply: onThresholdChanged,
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.notifyWhenWellbeingDrops((lowWellbeingThreshold * 100).toStringAsFixed(0)),
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
