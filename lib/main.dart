import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:Therapets/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_bootstrapper.dart';
import 'core/app_lifecycle_manager.dart';
import 'screens/game_screen.dart';
import 'services/locale_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Bootstrap all services and persistence
  final bootstrap = await AppBootstrapper.init();
  
  // 2. Initialize communication port between task isolate and main isolate.
  FlutterForegroundTask.initCommunicationPort();

  // 3. Initialize the foreground task plugin with conservative options.
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'therapets_fg',
      channelName: 'Therapets Service',
      channelDescription: 'Foreground service for keeping BLE active',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: bootstrap.cloudService),
        Provider.value(value: bootstrap.deviceService),
        Provider.value(value: bootstrap.missionService),
        Provider.value(value: bootstrap.telemetryTracker),
        Provider.value(value: bootstrap.petStats),
        Provider.value(value: bootstrap.notificationService),
        ChangeNotifierProvider.value(value: bootstrap.localeService),
      ],
      child: AppLifecycleManager(
        petStats: bootstrap.petStats,
        missionService: bootstrap.missionService,
        deviceService: bootstrap.deviceService,
        child: const TherapetsApp(),
      ),
    ),
  );
}

class TherapetsApp extends StatelessWidget {
  const TherapetsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();
    final appTextTheme = base.textTheme.apply(fontFamily: 'Monocraft', bodyColor: Colors.black);
    
    return Consumer<LocaleService>(
      builder: (context, localeService, _) {
        return MaterialApp(
          title: 'Therapets',
          locale: localeService.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
      },
    );
  }
}

// Compatibility shim for older tests that expect `MyApp`.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const TherapetsApp();
}
