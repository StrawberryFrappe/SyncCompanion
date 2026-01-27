import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
// Note: using bundled `Monocraft` font; removed runtime google_fonts usage.

import 'screens/game_screen.dart';
import 'services/cloud/cloud_service.dart';
import 'services/cloud/telemetry_tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for persistent storage
  await Hive.initFlutter();
  
  // Initialize cloud service (event queue + connectivity listener)
  await CloudService().init();
  
  // Initialize telemetry tracker (sync status monitoring)
  await TelemetryTracker().init();
  
  // Initialize communication port between task isolate and main isolate.
  FlutterForegroundTask.initCommunicationPort();

  // Initialize the foreground task plugin with conservative options.
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'sync_companion_fg',
      channelName: 'Therapets Service',
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
      title: 'Therapets',
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
      home: const GameScreen(),
    );
  }
}

// Compatibility shim for older tests that expect `MyApp`.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const SyncCompanionApp();
}

// `HomePage` and its implementation are moved into `lib/home_page.dart`.
