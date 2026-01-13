import 'package:flutter/material.dart';

/// Connection status indicator section.
class ConnectionStatusSection extends StatelessWidget {
  final bool isConnected;
  final bool nativeStatusReceived;
  final String? deviceId;

  const ConnectionStatusSection({
    super.key,
    required this.isConnected,
    required this.nativeStatusReceived,
    this.deviceId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(width: 2, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              Text(isConnected 
                  ? 'SYNCED' 
                  : (nativeStatusReceived ? 'SEARCHING' : 'LOADING'), 
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
        if (deviceId != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(width: 1, color: Colors.black)),
            child: Text(
              'Device: ${deviceId!.length > 12 ? '...${deviceId!.substring(deviceId!.length - 12)}' : deviceId}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ],
      ],
    );
  }
}
