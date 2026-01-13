import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/device/device_service.dart';

/// Terminal widget that displays raw incoming data from the device.
class TelemetryTerminal extends StatefulWidget {
  const TelemetryTerminal({super.key, required this.device, this.maxLines = 100});

  final DeviceService device;
  final int maxLines;

  @override
  State<TelemetryTerminal> createState() => _TelemetryTerminalState();
}

class _TelemetryTerminalState extends State<TelemetryTerminal> {
  final List<String> _lines = [];
  StreamSubscription<List<int>>? _sub;
  final ScrollController _scroll = ScrollController();
  DateTime? _lastPacketAt;

  @override
  void initState() {
    super.initState();
    _sub = widget.device.incomingRaw$.listen((bytes) {
      final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      setState(() {
        _lastPacketAt = DateTime.now();
        _lines.add(s);
        if (_lines.length > widget.maxLines) _lines.removeAt(0);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRecent = _lastPacketAt != null && DateTime.now().difference(_lastPacketAt!).inMilliseconds < 2000;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasRecent)
            const Text('— no recent packets —', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
          Expanded(
            child: Scrollbar(
              child: ListView.builder(
                controller: _scroll,
                itemCount: _lines.isEmpty ? 1 : _lines.length,
                itemBuilder: (ctx, i) {
                  if (_lines.isEmpty) return const Text('— no incoming packets yet —', style: TextStyle(fontSize: 10, fontFamily: 'monospace'));
                  return Text(_lines[i], style: const TextStyle(fontSize: 10, fontFamily: 'monospace'));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
