import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Note: using bundled `Monocraft` font; removed runtime google_fonts usage.

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveTaskHandler());
}

class _KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // no-op: the main isolate handles BLE; this task just keeps the process alive
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Send a lightweight heartbeat to main isolate; main can ignore if not needed
    FlutterForegroundTask.sendDataToMain({'heartbeat': timestamp.millisecondsSinceEpoch});
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // cleanup if needed
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize communication port between task isolate and main isolate.
  FlutterForegroundTask.initCommunicationPort();

  // Initialize the foreground task plugin with conservative options.
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'sync_companion_fg',
      channelName: 'Sync Companion Service',
      channelDescription: 'Foreground service for keeping BLE active',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  runApp(const SyncCompanionApp());
}

class SyncCompanionApp extends StatelessWidget {
  const SyncCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();
    final appTextTheme = base.textTheme.apply(fontFamily: 'Monocraft', bodyColor: Colors.black);
    return MaterialApp(
      title: 'Sync Companion',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        textTheme: appTextTheme,
        primaryTextTheme: appTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: appTextTheme.titleLarge?.copyWith(fontSize: 14) ?? const TextStyle(fontFamily: 'Monocraft', fontSize: 14),
          toolbarTextStyle: appTextTheme.bodyLarge,
        ),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: appTextTheme.bodyMedium)),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(textStyle: appTextTheme.bodyMedium)),
      ),
      home: const HomePage(),
    );
  }
}

// Compatibility shim for older tests that expect `MyApp`.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const SyncCompanionApp();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // use FlutterBluePlus static APIs directly
  final List<ScanResult> _found = [];
  // Notifier for live updates inside dialogs/routes that don't rebuild from
  // the parent `setState`. Use this to show devices as they arrive.
  final ValueNotifier<List<ScanResult>> _foundNotifier = ValueNotifier(const []);
  StreamSubscription? _scanSub;
  Timer? _scanStopTimer;
  DateTime? _lastScanStart;
  final Duration _scanDebounce = const Duration(seconds: 5);
  final Duration _scanTimeout = const Duration(seconds: 30);
  BluetoothDevice? _connectedDevice;
  // characteristic placeholder removed; we handle subscriptions directly
  Timer? _readTimer;
  String _incoming = '';
  String _status = 'SEARCHING';
  String? _savedId;
  bool _scanning = false;
  // platform channel to ask Android to enable Bluetooth and request permissions
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  String _adapterState = 'unknown';
  Map<String, bool> _permissionStatuses = {};
  final Map<String, String> _debugInfo = {};
  bool _bgServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _readTimer?.cancel();
    _foundNotifier.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // listen to adapter state so UI and scan logic can react
    // query platform for current adapter state
    try {
      final enabled = await _platform.invokeMethod('isBluetoothEnabled');
      setState(() => _adapterState = (enabled == true) ? 'ON' : 'OFF');
    } on PlatformException catch (e) {
      print('isBluetoothEnabled failed: $e');
    }
    await _requestPermissions();
    // check foreground service status
    try {
      final running = await FlutterForegroundTask.isRunningService;
      setState(() => _bgServiceRunning = running);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    _savedId = prefs.getString('saved_device_id');
    if (_savedId != null) {
      _autoReconnect(_savedId!);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final res = await _platform.invokeMethod('requestPermissions');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        setState(() {
          _permissionStatuses = map.map((k, v) => MapEntry(k.toString(), v == true));
        });
      }
    } on PlatformException catch (e) {
      print('permission request failed: $e');
    }
  }

  Future<void> _autoReconnect(String id) async {
    // keep trying until connected
    while (mounted && _connectedDevice == null) {
      try {
        setState(() => _status = 'SEARCHING');
        // use our debounced scanner for a short scan window
        await _startScan();
        await Future.delayed(const Duration(seconds: 4));
        ScanResult? match;
        for (final r in _found) {
          if (r.device.id.id == id) {
            match = r;
            break;
          }
        }
        await _stopScan();
        if (match != null) {
          await _connectTo(match.device, save: false);
          break;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _connectTo(BluetoothDevice device, {bool save = true}) async {
    try {
      setState(() => _status = 'CONNECTING');
      await device.connect(autoConnect: false).timeout(const Duration(seconds: 8));
      _connectedDevice = device;
      if (save) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_device_id', device.id.id);
        _savedId = device.id.id;
      }
      setState(() => _status = 'LINKED');
      final services = await device.discoverServices();
      // find first characteristic with notify or write; prefer notify
      BluetoothCharacteristic? chosen;
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.notify) {
            chosen = c;
            break;
          }
          if (chosen == null && (c.properties.write || c.properties.read)) {
            chosen = c;
          }
        }
        if (chosen != null) break;
      }
      if (chosen != null) {
        if (chosen.properties.notify) {
          await chosen.setNotifyValue(true);
          chosen.lastValueStream.listen((b) {
            final s = _decode(b);
            setState(() => _incoming = s);
          });
        } else if (chosen.properties.read) {
          _readTimer?.cancel();
          final c = chosen;
          _readTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
            try {
              final b = await c.read();
              final s = _decode(b);
              setState(() => _incoming = s);
            } catch (_) {}
          });
        }
      }
    } catch (e) {
      setState(() => _status = 'SEARCHING');
      try {
        await device.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }
  }

  String _decode(List<int> bytes) {
    try {
      if (bytes.isEmpty) return '';
      final s = utf8.decode(bytes);
      return s;
    } catch (_) {
      return bytes.toString();
    }
  }

  Future<void> _startScan() async {
    print('_startScan called; adapterState=$_adapterState, permissions=$_permissionStatuses, scanning=$_scanning, scanSub=${_scanSub != null}');
    // Ensure adapter is ON before attempting to scan
    final ok = await _ensureBluetoothOnBeforeScan();
    if (!ok) {
      setState(() {
        _status = 'BLUETOOTH_OFF';
      });
      return;
    }

    // debounce rapid start attempts
    final now = DateTime.now();
    if (_scanning) return;
    if (_scanSub != null) return;
    if (_lastScanStart != null && now.difference(_lastScanStart!) < _scanDebounce) return;
    _lastScanStart = now;

    _found.clear();
    setState(() => _scanning = true);
    // start a long-running scan; we'll stop it explicitly or after _scanTimeout
    try {
      print('Attempting FlutterBluePlus.startScan()');
      await FlutterBluePlus.startScan();
    } catch (e, st) {
      print('startScan threw: $e');
      print(st);
    }
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.id.id;
        // store debug info for diagnostics
        try {
          _debugInfo[id] = 'rssi:${r.rssi} adv:${r.advertisementData}';
        } catch (_) {
          _debugInfo[id] = 'rssi:${r.rssi}';
        }
        // Additional verbose diagnostic printing
        try {
          print('scanResult: id=$id name=${r.device.name} rssi=${r.rssi} adv=${r.advertisementData}');
        } catch (_) {
          print('scanResult: id=$id rssi=${r.rssi}');
        }
        if (!_found.any((e) => e.device.id.id == id)) {
          // keep a local copy for legacy uses
          _found.add(r);
          // publish to notifier for UI that lives in the dialog route
          _foundNotifier.value = List<ScanResult>.from(_foundNotifier.value)..add(r);
          // refresh any parent UI that still depends on _found
          setState(() {});
        } else {
          // update debug payload or rssi updates
          setState(() {});
        }
      }
      // diagnostic log of raw results each time
      try {
        print('scanResults: ${results.map((r) => r.device.id.id).toList()}');
      } catch (_) {}
    }, onError: (e) {
      print('scanResults stream error: $e');
    });
    // schedule an auto-stop in case user doesn't stop manually
    _scanStopTimer?.cancel();
    _scanStopTimer = Timer(_scanTimeout, () async {
      await _stopScan();
    });
  }

  Future<void> _startBackgroundTask() async {
    if (await FlutterForegroundTask.isRunningService) return;
    // Ensure required runtime permissions are granted first
    await _requestPermissions();
    final scanOk = _permissionStatuses['android.permission.BLUETOOTH_SCAN'] == true || _permissionStatuses['BLUETOOTH_SCAN'] == true;
    final connectOk = _permissionStatuses['android.permission.BLUETOOTH_CONNECT'] == true || _permissionStatuses['BLUETOOTH_CONNECT'] == true;
    if (!scanOk || !connectOk) {
      // prompt user to allow permissions in Settings if request couldn't get them
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Permissions required', style: TextStyle(fontSize: 12)),
        content: const Text('Bluetooth permissions are required to run in background. Please grant them in Settings.', style: TextStyle(fontSize: 10)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK', style: TextStyle(fontSize: 10))),
        ],
      ));
      return;
    }

    // respect user preference for notification visibility
    final prefs = await SharedPreferences.getInstance();
    final showNotification = prefs.getBool('show_sync_notification') ?? true;
    final notifText = (_connectedDevice != null && showNotification) ? 'The device is synced' : (_connectedDevice != null ? 'Connected' : (showNotification ? 'Running in background' : '')) ;

    try {
      await FlutterForegroundTask.startService(
        serviceId: 1,
        notificationTitle: 'Sync Companion',
        notificationText: notifText,
        callback: startCallback,
      );
      setState(() => _bgServiceRunning = true);
    } catch (e) {
      // Starting the foreground service may throw if the app lacks the
      // required Android foreground/location permissions. Show guidance.
      print('startBackgroundTask failed: $e');
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Background service failed', style: TextStyle(fontSize: 12)),
        content: const Text('Could not start the foreground background service. Please ensure the app has the required permissions (location/foreground service) in Android settings.', style: TextStyle(fontSize: 10)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK', style: TextStyle(fontSize: 10))),
        ],
      ));
    }
  }

  Future<void> _stopBackgroundTask() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
    setState(() => _bgServiceRunning = false);
  }

  Future<void> _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
    _scanStopTimer?.cancel();
    _scanStopTimer = null;
    if (mounted) setState(() => _scanning = false);
  }

  Future<bool> _ensureBluetoothOnBeforeScan() async {
    try {
      final enabledNow = await _platform.invokeMethod('isBluetoothEnabled');
      if (enabledNow == true) return true;
      // show dialog asking user to enable
      final pressed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Bluetooth Disabled', style: TextStyle(fontSize: 12)),
          content: const Text('Bluetooth needs to be enabled to scan for devices.', style: TextStyle(fontSize: 10)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('CANCEL', style: TextStyle(fontSize: 10)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(c).pop(true);
              },
              child: const Text('ENABLE BLUETOOTH', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      );
      if (pressed != true) return false;
      // ask platform to present system enable intent
      bool enabled = false;
      try {
        enabled = await _platform.invokeMethod('enableBluetooth') == true;
      } on PlatformException catch (e) {
        print('enable intent failed: $e');
      }
      // poll for adapter state briefly via platform
      for (int i = 0; i < 10; i++) {
        final now = await _platform.invokeMethod('isBluetoothEnabled');
        if (now == true) return true;
        await Future.delayed(const Duration(milliseconds: 300));
      }
      return enabled;
    } catch (e) {
      print('ensureBluetoothOnBeforeScan error: $e');
      return false;
    }
  }

  Future<void> _forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_device_id');
    _savedId = null;
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    // characteristic cleared
    _readTimer?.cancel();
    setState(() {
      _incoming = '';
      _status = 'SEARCHING';
    });
  }

  void _openScanner() async {
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          // increase vertical size so more devices are visible at once
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Diagnostics + incoming data moved into Settings dialog
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adapter: $_adapterState', style: const TextStyle(fontSize: 8)),
                    const SizedBox(height: 4),
                    Text('Perms: ${_permissionStatuses.entries.map((e) => '${e.key.split('.').last}:${e.value?"Y":"N"}').join(', ')}', style: const TextStyle(fontSize: 8)),
                    const SizedBox(height: 6),
                    if (_connectedDevice != null)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(border: Border.all(width: 2, color: Colors.black)),
                        child: SingleChildScrollView(
                          child: Text(
                            '${_connectedDevice!.name.isNotEmpty ? _connectedDevice!.name : _connectedDevice!.id.id}\n${_incoming.isEmpty ? '—' : _incoming}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Background service controls: service runs automatically.
              // Provide a user preference to control whether the persistent
              // sync notification is shown. Note: Android requires a
              // foreground service to display a notification while running;
              // so the service will keep running even if the user chooses to
              // 'hide' the notification — on Android this may be limited by
              // OS rules; we at least store the user's preference and try to
              // update the notification text accordingly.
              FutureBuilder<bool>(
                future: SharedPreferences.getInstance().then((p) => p.getBool('show_sync_notification') ?? true),
                builder: (ctx, snap) {
                  final show = snap.data ?? true;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Show sync notification', style: TextStyle(fontSize: 10)),
                      TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final newVal = !(prefs.getBool('show_sync_notification') ?? true);
                          await prefs.setBool('show_sync_notification', newVal);
                          setState(() {});
                          // If service is running, try to restart it with updated text
                          if (_bgServiceRunning) {
                            try {
                              await _stopBackgroundTask();
                            } catch (_) {}
                            await _startBackgroundTask();
                          }
                        },
                        child: Text(show ? 'ON' : 'OFF', style: const TextStyle(fontSize: 10)),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SCAN', style: TextStyle(fontSize: 10)),
                  IconButton(
                    icon: Icon(_scanning ? Icons.stop : Icons.refresh, color: Colors.black),
                    onPressed: () async {
                      if (_scanning) {
                        await _stopScan();
                      } else {
                        _found.clear();
                        await _startScan();
                      }
                    },
                  )
                ],
              ),
              const Divider(color: Colors.black, thickness: 2),
              // Use a ValueListenableBuilder so the dialog updates live as devices
              // are discovered without relying on parent `setState` rebuilding
              // the dialog route.
              Expanded(
                child: ValueListenableBuilder<List<ScanResult>>(
                  valueListenable: _foundNotifier,
                  builder: (ctx, found, _) {
                    return ListView.separated(
                      itemCount: found.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.black, thickness: 2),
                      itemBuilder: (ctx2, i) {
                        final r = found[i];
                        final name = r.device.name.isNotEmpty ? r.device.name : r.device.id.id;
                        return ListTile(
                          title: Text(name, style: const TextStyle(fontSize: 10)),
                          subtitle: Text('${r.device.id.id}\n${_debugInfo[r.device.id.id] ?? ''}', style: const TextStyle(fontSize: 8)),
                          onTap: () async {
                            await _stopScan();
                            Navigator.of(context).pop();
                            await _connectTo(r.device, save: true);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              if (_connectedDevice != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(width: 2, color: Colors.black)),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _forget();
                  },
                  child: const Text('Disconnect & Forget', style: TextStyle(fontSize: 10)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SYNC COMPANION', style: const TextStyle(fontSize: 14, fontFamily: 'Monocraft')),
        centerTitle: true,
        toolbarHeight: 56,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact status row: indicator + text (no surrounding box or settings button)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _connectedDevice != null ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(width: 2, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_connectedDevice != null ? 'CONNECTED' : _status, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Placeholder image between the status indicator and the settings button
            Center(
              child: SizedBox(
                height: 80,
                child: Image.asset('placeholder.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(width: 2, color: Colors.black)),
                    onPressed: _openScanner,
                    child: const Text('SETTINGS', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
