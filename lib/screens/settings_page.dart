import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_service.dart' as bt_service;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.bt});

  final bt_service.BluetoothService bt;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifShowData = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool('notif_show_data');
    setState(() {
      _notifShowData = v == null ? true : v;
      _loading = false;
    });
  }

  Future<void> _setShowData(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_show_data', v);
    setState(() => _notifShowData = v);
    // Tell native service to refresh its notification immediately.
    try {
      await widget.bt.updateNativeNotification();
    } catch (_) {}
  }

  Future<void> _openScanner() async {
    // Use the passed BluetoothService to scan and connect
    final bt = widget.bt;
    await bt.startScan(timeout: const Duration(seconds: 7));
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: bt.foundDevices$,
                  builder: (ctx, snap) {
                    final found = snap.data ?? const [];
                    return ListView.separated(
                      itemCount: found.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.black, thickness: 2),
                      itemBuilder: (ctx2, i) {
                        final r = found[i];
                        final idStr = r.device.remoteId.str;
                        final name = (r.device.platformName.isNotEmpty ? r.device.platformName : idStr);
                        final shortId = idStr.length > 6 ? idStr.substring(idStr.length - 6) : idStr;
                        return ListTile(
                          title: Text(name, style: const TextStyle(fontSize: 12)),
                          subtitle: Text('RSSI: ${r.rssi} dBm', style: const TextStyle(fontSize: 10)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(border: Border.all(width: 1, color: Colors.black), borderRadius: BorderRadius.circular(4)),
                            child: Text(shortId, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                          ),
                          onTap: () async {
                            await bt.stopScan();
                            Navigator.of(context).pop();
                            try {
                              await bt.connect(r.device, save: true);
                            } catch (_) {}
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await bt.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontSize: 14))),
      body: ListView(
        children: [
          StreamBuilder<bool>(
            stream: widget.bt.nativeConnected$,
            builder: (ctx, snap) {
              final connected = snap.data ?? false;
              if (!connected) return const SizedBox.shrink();
              final id = widget.bt.getSavedDeviceId();
              final label = id != null ? 'Connected: ${id.substring(id.length - (id.length > 8 ? 8 : id.length))}' : 'Connected';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(width: 2, color: Colors.black)),
                          onPressed: () async {
                            await widget.bt.disconnect();
                          },
                          child: const Text('DISCONNECT', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(width: 2, color: Colors.black)),
                          onPressed: () async {
                            await widget.bt.forget();
                          },
                          child: const Text('FORGET', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ]),
                    const Divider(color: Colors.black, thickness: 2),
                  ],
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Notification: show live data', style: TextStyle(fontSize: 12)),
            subtitle: const Text('When off, notification shows "Your device is synced"', style: TextStyle(fontSize: 10)),
            value: _notifShowData,
            onChanged: (v) => _setShowData(v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(width: 2, color: Colors.black)),
              onPressed: _openScanner,
              child: const Text('SCAN FOR DEVICES', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
