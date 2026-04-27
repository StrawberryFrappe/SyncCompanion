import 'package:Therapets/services/cloud/telemetry_tracker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../game/missions/daily_missions.dart';
import '../game/missions/mission_service.dart';
import '../game/pets/pet_stats.dart';
import '../services/cloud/cloud_service.dart';
import '../services/device/device_service.dart';
import '../services/locale_service.dart';
import '../services/notifications/pet_notification_service.dart';

/// Result of the bootstrap process.
class BootstrapResult {
  final LocaleService localeService;
  final CloudService cloudService;
  final DeviceService deviceService;
  final MissionService missionService;
  final TelemetryTracker telemetryTracker;
  final PetStats petStats;
  final PetNotificationService notificationService;

  BootstrapResult({
    required this.localeService,
    required this.cloudService,
    required this.deviceService,
    required this.missionService,
    required this.telemetryTracker,
    required this.petStats,
    required this.notificationService,
  });
}

/// Orchestrates the app startup sequence.
/// Ensures all services are initialized in the correct order.
class AppBootstrapper {
  static Future<BootstrapResult> init() async {
    debugPrint('[Bootstrapper] STARTING');

    // 1. Initialize Hive
    await Hive.initFlutter();
    _registerAdapters();

    // 2. Open Boxes
    final statsBox = await Hive.openBox<PetStats>('pet_stats_box');
    final missionBox = await Hive.openBox('missions_box');

    // 3. Initialize Services (Leaf dependencies first)
    final localeService = LocaleService();
    await localeService.init();

    final cloudService = CloudService();
    await cloudService.init();

    final deviceService = DeviceService();
    await deviceService.init();

    // 4. Load/Migrate PetStats
    PetStats petStats = await _loadOrMigratePetStats(statsBox, deviceService);

    // 5. Initialize Services that depend on others
    final missionService = MissionService(cloudService: cloudService);
    await missionService.init(petStats, missionBox);

    final telemetryTracker = TelemetryTracker(
      deviceService: deviceService,
      cloudService: cloudService,
    );
    await telemetryTracker.init();

    final notificationService = PetNotificationService(localeService: localeService);

    debugPrint('[Bootstrapper] COMPLETE');

    return BootstrapResult(
      localeService: localeService,
      cloudService: cloudService,
      deviceService: deviceService,
      missionService: missionService,
      telemetryTracker: telemetryTracker,
      petStats: petStats,
      notificationService: notificationService,
    );
  }

  static void _registerAdapters() {
    Hive.registerAdapter(PetStatsAdapter());
    Hive.registerAdapter(SyncDurationMissionAdapter());
    Hive.registerAdapter(MinigamePlayMissionAdapter());
    Hive.registerAdapter(FeedPetMissionAdapter());
  }

  static Future<PetStats> _loadOrMigratePetStats(
    Box<PetStats> box,
    DeviceService deviceService,
  ) async {
    if (box.isNotEmpty) {
      final stats = box.getAt(0)!;
      // Apply background updates immediately on load
      final isSynced = deviceService.currentDisplayStatus == DeviceDisplayStatus.synced;
      stats.applyBackgroundUpdates(wasDeviceSynced: isSynced);
      return stats;
    }

    // Migration from SharedPreferences
    debugPrint('[Bootstrapper] MIGRATING PetStats from SharedPreferences');
    final stats = PetStats();
    final isSynced = deviceService.currentDisplayStatus == DeviceDisplayStatus.synced;
    await stats.loadFromPrefs(isDeviceSynced: isSynced);
    
    // Save to Hive immediately
    await box.add(stats);
    
    // Optional: Clear SharedPreferences bundle key after successful migration
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.remove('pet_stats_bundle');
    
    return stats;
  }
}
