import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';

class AppUpdatesSection extends StatelessWidget {
  final bool nightlyEnabled;
  final ValueChanged<bool> onNightlyChanged;

  const AppUpdatesSection({
    super.key,
    required this.nightlyEnabled,
    required this.onNightlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.appUpdates,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Monocraft',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: SwitchListTile(
            title: Text(
              AppLocalizations.of(context)!.nightlyUpdates,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            subtitle: Text(
              AppLocalizations.of(context)!.nightlyUpdatesDesc,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            value: nightlyEnabled,
            onChanged: onNightlyChanged,
            activeColor: Colors.blueAccent,
          ),
        ),
      ],
    );
  }
}
