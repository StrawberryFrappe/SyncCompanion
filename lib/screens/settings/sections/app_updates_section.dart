import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';

class AppUpdatesSection extends StatelessWidget {
  final bool nightlyEnabled;
  final ValueChanged<bool> onNightlyChanged;
  final bool unstableEnabled;
  final ValueChanged<bool> onUnstableChanged;

  const AppUpdatesSection({
    super.key,
    required this.nightlyEnabled,
    required this.onNightlyChanged,
    required this.unstableEnabled,
    required this.onUnstableChanged,
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
          child: Column(
            children: [
              SwitchListTile(
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
              if (nightlyEnabled) ...[
                const Divider(height: 1, color: Colors.grey),
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: SwitchListTile(
                    title: Text(
                      AppLocalizations.of(context)!.unstableUpdates,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)!.unstableUpdatesDesc,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    value: unstableEnabled,
                    onChanged: onUnstableChanged,
                    activeColor: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
