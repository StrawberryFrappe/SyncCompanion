import 'dart:async';
import 'package:flutter/material.dart';
import '../game/virtual_pet_game.dart';
import '../services/device/device_service.dart';
import '../services/cloud/cloud_service.dart';
import '../game/missions/mission_service.dart';
import '../services/notifications/pet_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameScreenController extends ChangeNotifier {
  final VirtualPetGame game;
  final DeviceService deviceService;
  
  bool _isPaused = false;
  int _backgroundSyncSeconds = 0;
  DateTime? _backgroundSyncStartTime;
  
  Timer? _autoSaveTimer;
  Timer? _uiUpdateTimer;
  Timer? _backgroundTicker;

  DeviceDisplayStatus connectionStatus = DeviceDisplayStatus.searching;
  StreamSubscription? _syncSub;

  GameScreenController({
    required this.game,
    required this.deviceService,
  }) {
    _init();
  }

  void _init() {
    connectionStatus = deviceService.currentDisplayStatus;
    _syncSub = deviceService.displayStatus$.listen((status) {
      connectionStatus = status;
      game.setSyncStatus(status == DeviceDisplayStatus.synced);
      notifyListeners();
    });

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) => saveStats());

    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      MissionService().update(MissionContext(
        dt: 1.0,
        isDeviceSynced: connectionStatus == DeviceDisplayStatus.synced,
      ));
      notifyListeners();
    });

    _backgroundTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused && game.isReady) {
        final isSynced = connectionStatus == DeviceDisplayStatus.synced;
        game.currentPet.stats.update(1.0, isDeviceSynced: isSynced);
        
        if (isSynced) {
          _backgroundSyncStartTime ??= DateTime.now();
          _backgroundSyncSeconds++;
        } else if (_backgroundSyncSeconds > 0) {
          _flushBackgroundSession();
        }
      }
    });

    _initialize();
  }

  bool _isInitializing = false;

  Future<void> _initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;
    
    try {
      debugPrint('[Controller] INIT START');
      await loadPersistedRates();
      await restoreStats();
      await game.initialized;
      await MissionService().init(game.currentPet.stats);
      debugPrint('[Controller] INIT COMPLETE');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> loadPersistedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final hungerRate = prefs.getDouble('pet_hunger_decay_rate');
    final happinessGain = prefs.getDouble('pet_happiness_gain_rate');
    final happinessDecay = prefs.getDouble('pet_happiness_decay_rate');
    final lowWellbeingThreshold = prefs.getDouble('pet_low_wellbeing_threshold') ?? 0.25;
    
    game.setStatRates(
      hungerDecayRate: hungerRate,
      happinessGainRate: happinessGain,
      happinessDecayRate: happinessDecay,
    );
    
    await game.initialized;
    game.currentPet.stats.lowWellbeingThreshold = lowWellbeingThreshold;
    game.currentPet.stats.onLowWellbeing = () {
      PetNotificationService().showLowWellbeingNotification();
    };
  }

  Future<void> restoreStats() async {
    await game.loadPetStats(isDeviceSynced: false);
  }

  void _flushBackgroundSession() {
    if (_backgroundSyncSeconds > 0 && _backgroundSyncStartTime != null) {
      CloudService().logSyncSession(
        duration: Duration(seconds: _backgroundSyncSeconds),
        startTime: _backgroundSyncStartTime!,
      );
      _backgroundSyncSeconds = 0;
      _backgroundSyncStartTime = null;
    }
  }

  Future<void> saveStats() async {
    try {
      await game.savePetStats();
      await MissionService().save();
    } catch (e) {
      debugPrint('Error saving stats: $e');
    }
  }

  Future<void> handleLifecycleChange(AppLifecycleState state) async {
    debugPrint('[Controller] LIFECYCLE: $state');
    switch (state) {
      case AppLifecycleState.paused:
        _isPaused = true;
        await saveStats();
        break;
      case AppLifecycleState.resumed:
        _isPaused = false;
        _flushBackgroundSession();
        deviceService.onAppResumed();
        // Only reload if we are NOT currently initializing to avoid races
        if (!_isInitializing) {
          await game.loadPetStats(isDeviceSynced: false);
        }
        break;
      case AppLifecycleState.detached:
        await saveStats();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _autoSaveTimer?.cancel();
    _uiUpdateTimer?.cancel();
    _backgroundTicker?.cancel();
    saveStats(); // Note: cannot await in dispose, but autoSaveTimer is gone
    super.dispose();
  }
}
