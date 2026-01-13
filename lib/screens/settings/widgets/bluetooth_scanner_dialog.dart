import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../services/device/device_service.dart';
import 'telemetry_terminal.dart';

/// A dialog for scanning and connecting to Bluetooth devices.
/// Shows a list of discovered devices when not connected, or a telemetry
/// terminal when connected.
class BluetoothScannerDialog extends StatefulWidget {
  final DeviceService device;
  final BluetoothDevice? connectedDevice;
  final String? persistedDeviceId;
  final String adapterState;
  final Map<String, bool> permissionStatuses;
  final VoidCallback onForget;
  final Future<void> Function(BluetoothDevice device) onConnect;

  const BluetoothScannerDialog({
    super.key,
    required this.device,
    required this.connectedDevice,
    required this.persistedDeviceId,
    required this.adapterState,
    required this.permissionStatuses,
    required this.onForget,
    required this.onConnect,
  });

  @override
  State<BluetoothScannerDialog> createState() => _BluetoothScannerDialogState();
}

class _BluetoothScannerDialogState extends State<BluetoothScannerDialog> {
  bool _scanning = false;
  final Duration _scanTimeout = const Duration(seconds: 7);

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      await widget.device.startScan(timeout: _scanTimeout);
    } catch (e) {
      debugPrint('startScan error: $e');
    }
  }

  Future<void> _stopScan() async {
    try {
      await widget.device.stopScan();
    } catch (_) {}
    if (mounted) {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status info section
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adapter: ${widget.adapterState}', style: const TextStyle(fontSize: 8)),
                  const SizedBox(height: 4),
                  Text(
                    'Perms: ${widget.permissionStatuses.entries.map((e) => '${e.key.split('.').last}:${e.value ? "Y" : "N"}').join(', ')}',
                    style: const TextStyle(fontSize: 8),
                  ),
                  const SizedBox(height: 6),
                  if (widget.connectedDevice != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
                      child: SingleChildScrollView(
                        child: Text(
                          widget.connectedDevice!.platformName.isNotEmpty
                              ? widget.connectedDevice!.platformName
                              : widget.connectedDevice!.remoteId.str,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  if (widget.connectedDevice == null && widget.persistedDeviceId != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
                      child: Text(
                        'Persisted: ${widget.persistedDeviceId}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Main content: terminal or scan results
            Expanded(
              child: widget.connectedDevice != null
                  ? TelemetryTerminal(device: widget.device, maxLines: 200)
                  : StreamBuilder<List<ScanResult>>(
                      stream: widget.device.foundDevices$,
                      builder: (ctx, snap) {
                        final found = snap.data ?? const [];
                        return ListView.separated(
                          itemCount: found.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.black, thickness: 2),
                          itemBuilder: (ctx2, i) {
                            final r = found[i];
                            final idStr = r.device.remoteId.str;
                            final name = r.device.platformName.isNotEmpty ? r.device.platformName : idStr;
                            final shortId = idStr.length > 6 ? idStr.substring(idStr.length - 6) : idStr;
                            return ListTile(
                              title: Text(name, style: const TextStyle(fontSize: 12)),
                              subtitle: Text('RSSI: ${r.rssi} dBm', style: const TextStyle(fontSize: 10)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(width: 1, color: Colors.black),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(shortId, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                              ),
                              onTap: () async {
                                await _stopScan();
                                Navigator.of(context).pop();
                                await widget.onConnect(r.device);
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
            if (widget.connectedDevice != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(width: 2, color: Colors.black),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onForget();
                },
                child: const Text('Disconnect & Forget', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }
}
