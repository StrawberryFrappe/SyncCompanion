import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';
import '../../../services/cloud/cloud_service.dart';

/// Cloud Sync settings section.
class CloudSyncSection extends StatelessWidget {
  final CloudService cloud;
  final String baseUrl;
  final String deviceToken;
  final VoidCallback onConfigure;
  final VoidCallback onFlushQueue;

  const CloudSyncSection({
    super.key,
    required this.cloud,
    required this.baseUrl,
    required this.deviceToken,
    required this.onConfigure,
    required this.onFlushQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(width: 2, color: Colors.purple),
        color: Colors.purple.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.cloudSync, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(AppLocalizations.of(context)!.pending(cloud.pendingEventCount), 
                style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(width: 1, color: Colors.black26),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.baseUrlLabel, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                Text(baseUrl.isEmpty ? AppLocalizations.of(context)!.notSet : baseUrl,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context)!.deviceTokenLabel, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                Text(deviceToken.isEmpty ? AppLocalizations.of(context)!.notSet : deviceToken,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade100,
                    foregroundColor: Colors.black,
                    side: const BorderSide(width: 1, color: Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onPressed: onConfigure,
                  child: Text(AppLocalizations.of(context)!.configure, style: const TextStyle(fontSize: 9)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.black,
                    side: const BorderSide(width: 1, color: Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onPressed: onFlushQueue,
                  child: Text(AppLocalizations.of(context)!.flushQueue, style: const TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
