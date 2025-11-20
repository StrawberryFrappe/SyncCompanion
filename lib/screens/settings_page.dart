import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

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
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontSize: 14))),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Notification: show live data', style: TextStyle(fontSize: 12)),
            subtitle: const Text('When off, notification shows "Your device is synced"', style: TextStyle(fontSize: 10)),
            value: _notifShowData,
            onChanged: (v) => _setShowData(v),
          ),
        ],
      ),
    );
  }
}
