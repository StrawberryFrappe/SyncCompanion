import 'package:flutter/material.dart';
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
              const Text('CLOUD SYNC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('${cloud.pendingEventCount} pending', 
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
                const Text('Base URL:', style: TextStyle(fontSize: 9, color: Colors.grey)),
                Text(baseUrl.isEmpty ? '(not set)' : baseUrl,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text('Device Token:', style: TextStyle(fontSize: 9, color: Colors.grey)),
                Text(deviceToken.isEmpty ? '(not set)' : deviceToken,
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
                  child: const Text('CONFIGURE', style: TextStyle(fontSize: 9)),
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
                  child: const Text('FLUSH QUEUE', style: TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
