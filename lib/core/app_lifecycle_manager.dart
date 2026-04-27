import 'package:flutter/material.dart';
import '../game/missions/mission_service.dart';
import '../game/pets/pet_stats.dart';
import '../services/device/device_service.dart';

/// Manages the application lifecycle.
/// Flushes persistent state to disk when the app is paused or detached.
class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  final PetStats petStats;
  final MissionService missionService;
  final DeviceService deviceService;

  const AppLifecycleManager({
    super.key,
    required this.child,
    required this.petStats,
    required this.missionService,
    required this.deviceService,
  });

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[LifecycleManager] STATE: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _flushState();
        break;
      case AppLifecycleState.resumed:
        _onResumed();
        break;
      default:
        break;
    }
  }

  Future<void> _flushState() async {
    debugPrint('[LifecycleManager] FLUSHING STATE');
    // In Phase 2, PetStats and Missions are in Hive boxes.
    // Hive's put/add are usually atomic, but we can call save() if we have custom logic.
    // For now, PetStats.saveToPrefs was using SharedPreferences. 
    // We should ensure Hive is flushed if needed.
    await widget.petStats.save(); // This should be updated to Hive logic
    await widget.missionService.save(); // This should be updated to Hive logic
  }

  Future<void> _onResumed() async {
    debugPrint('[LifecycleManager] RESUMED');
    await widget.deviceService.onAppResumed();
    // Re-load stats if needed (Hive might have been updated by background service)
    // widget.petStats.loadFromHive(); 
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
