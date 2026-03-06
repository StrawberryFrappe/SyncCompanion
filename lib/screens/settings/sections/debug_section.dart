import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';
import '../../../game/missions/mission_service.dart';

/// Debug settings section (Fake Sync, Missions Reset, Debug Info).
class DebugSection extends StatelessWidget {
  final bool fakeSyncEnabled;
  final bool fakeSyncValue;
  final ValueChanged<bool?> onFakeSyncEnabledChanged;
  final ValueChanged<bool?> onFakeSyncValueChanged;
  const DebugSection({
    super.key,
    required this.fakeSyncEnabled,
    required this.fakeSyncValue,
    required this.onFakeSyncEnabledChanged,
    required this.onFakeSyncValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fake Sync Toggle
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.orange),
            color: Colors.orange.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.debugFakeSync, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: fakeSyncEnabled,
                    onChanged: onFakeSyncEnabledChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Text(AppLocalizations.of(context)!.overrideSyncStatus, style: const TextStyle(fontSize: 10)),
                ],
              ),
              if (fakeSyncEnabled) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(AppLocalizations.of(context)!.synced, style: const TextStyle(fontSize: 9)),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(AppLocalizations.of(context)!.notSynced, style: const TextStyle(fontSize: 9)),
                        ),
                      ],
                      selected: {fakeSyncValue},
                      onSelectionChanged: (Set<bool> newSelection) {
                        if (newSelection.isNotEmpty) {
                          onFakeSyncValueChanged(newSelection.first);
                        }
                      },
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Reset Missions
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: Colors.orange),
            color: Colors.orange.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.debugMissions, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.black,
                  side: const BorderSide(width: 1, color: Colors.black),
                ),
                onPressed: () async {
                  await MissionService().forceResetMissions();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.dailyMissionsReset), duration: const Duration(seconds: 2)),
                    );
                  }
                },
                child: Text(AppLocalizations.of(context)!.resetDailyMissions, style: const TextStyle(fontSize: 10)),
              ),
              const SizedBox(height: 4),
              Text(AppLocalizations.of(context)!.forceRegenMissions, 
                style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
