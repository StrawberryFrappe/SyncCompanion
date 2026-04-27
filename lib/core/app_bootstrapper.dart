import 'package:Therapets/services/cloud/telemetry_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    try {
      await Hive.initFlutter().timeout(const Duration(seconds: 5));
      _registerAdapters();
    } catch (e) {
      debugPrint('[Bootstrapper] Hive initialization failed: $e');
    }

    // 2. Open Boxes with timeouts
    Box<PetStats>? statsBox;
    Box? missionBox;
    try {
      statsBox = await Hive.openBox<PetStats>('pet_stats_box').timeout(const Duration(seconds: 5));
      missionBox = await Hive.openBox('missions_box').timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[Bootstrapper] Failed to open Hive boxes: $e');
    }

    // 3. Initialize Services (Leaf dependencies first)
    final localeService = LocaleService();
    try {
      await localeService.init().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[Bootstrapper] LocaleService init failed: $e');
    }

    final cloudService = CloudService();
    try {
      await cloudService.init().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[Bootstrapper] CloudService init failed: $e');
    }

    final deviceService = DeviceService();
    try {
      await deviceService.init().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[Bootstrapper] DeviceService init failed: $e');
    }

    // 4. Load/Migrate PetStats (Safe even if box is null)
    PetStats petStats;
    if (statsBox != null) {
      petStats = await _loadOrMigratePetStats(statsBox, deviceService);
    } else {
      debugPrint('[Bootstrapper] Falling back to default PetStats (Hive unavailable)');
      petStats = PetStats();
    }

    // 5. Initialize Services that depend on others
    final missionService = MissionService(cloudService: cloudService);
    if (missionBox != null) {
      try {
        await missionService.init(petStats, missionBox).timeout(const Duration(seconds: 5));
        
        // Rehydrate background progress for missions (e.g. sync duration)
        final lastUpdateMs = petStats.lastUpdateTime.millisecondsSinceEpoch;
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsedSec = (now - lastUpdateMs) / 1000.0;
        final isSynced = deviceService.currentDisplayStatus == DeviceDisplayStatus.synced;
        
        await missionService.rehydrateBackgroundProgress(elapsedSec, isSynced);
      } catch (e) {
        debugPrint('[Bootstrapper] MissionService init failed: $e');
      }
    }

    final telemetryTracker = TelemetryTracker(
      deviceService: deviceService,
      cloudService: cloudService,
    );
    try {
      await telemetryTracker.init().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[Bootstrapper] TelemetryTracker init failed: $e');
    }

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
      
      // Calculate background elapsed time immediately
      final now = DateTime.now();
      final lastUpdateMs = stats.lastUpdateTime.millisecondsSinceEpoch;
      final elapsedSec = (now.millisecondsSinceEpoch - lastUpdateMs) / 1000.0;

      // Task 3: Check if background service has newer stats in SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final nativeUpdateMs = prefs.getInt('pet_last_update');
        
        if (nativeUpdateMs != null && nativeUpdateMs > lastUpdateMs) {
          debugPrint('[Bootstrapper] Native service has NEWER stats. Rehydrating.');
          
          // Try bundle first (Atomic)
          final bundleJson = prefs.getString('pet_stats_bundle');
          if (bundleJson != null) {
            try {
              final Map<String, dynamic> bundle = jsonDecode(bundleJson);
              stats.rehydrateFromMap(bundle);
            } catch (e) {
              debugPrint('[Bootstrapper] Bundle parse error: $e');
            }
          } else {
            // Fallback to individual keys
            stats.hunger = prefs.getDouble('pet_hunger') ?? stats.hunger;
            stats.happiness = prefs.getDouble('pet_happiness') ?? stats.happiness;
          }
        }
      } catch (e) {
        debugPrint('[Bootstrapper] Failed to check native rehydration: $e');
      }

      // Apply background updates (decay/gain) for the time since last update
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
