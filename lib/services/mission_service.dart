import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import '../game/missions/mission.dart';
import '../game/pets/pet_stats.dart';
import 'cloud_service.dart';

/// Service to manage daily missions.
class MissionService {
  static final MissionService _instance = MissionService._internal();
  factory MissionService() => _instance;
  MissionService._internal();

  List<Mission> _activeMissions = [];
  List<Mission> get activeMissions => List.unmodifiable(_activeMissions);

  // Stream for UI updates
  final _missionUpdateController = StreamController<List<Mission>>.broadcast();
  Stream<List<Mission>> get missionUpdates => _missionUpdateController.stream;

  // Stream for completion events (to show UI banners)
  final _completionController = StreamController<Mission>.broadcast();
  Stream<Mission> get missionCompletions => _completionController.stream;

  DateTime _lastResetDate = DateTime.now();

  PetStats? _petStats;

  /// Initialize with PetStats reference
  Future<void> init(PetStats stats) async {
    _petStats = stats;
    await _loadMissions();
    _checkDailyReset();
  }

  /// Update all active missions with new context
  void update(MissionContext ctx) {
    bool stateChanged = false;

    for (final mission in _activeMissions) {
      if (!mission.isCompleted) {
        final justCompleted = mission.update(ctx);
        if (justCompleted) {
          _handleMissionCompletion(mission);
          stateChanged = true;
        } else if (mission.progress > 0) {
          // If progress changed but not completed, we might still want to notify UI
          // For optimization, maybe only notify periodically or on significant change
          stateChanged = true; 
        }
      }
    }

    if (stateChanged) {
      _notifyListeners();
    }
  }

  void _handleMissionCompletion(Mission mission) {
    if (_petStats != null) {
      _petStats!.applyMissionReward(mission.goldReward, mission.happinessReward);
    }
    
    // Log to cloud
    CloudService().logMissionCompleted(
      missionId: mission.id, 
      missionTitle: mission.title
    );
    
    // Notify UI for banner
    _completionController.add(mission);
    
    _saveProgress();
  }

  Future<void> _checkDailyReset() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastReset = DateTime(_lastResetDate.year, _lastResetDate.month, _lastResetDate.day);

    if (today.isAfter(lastReset)) {
      await _generateDailyMissions();
    }
  }

  Future<void> _generateDailyMissions() async {
    // Generate 3 random missions for the day
    // In a real app, use a seed based on the date so it's deterministic
    final missions = <Mission>[
      SyncDurationMission(targetDuration: 30 * 60, rewardGold: 50), // 30 mins
      MinigamePlayMission(targetPlays: 3, rewardGold: 30),
      FeedPetMission(targetFeeds: 3, rewardGold: 20),
    ];
    
    _activeMissions = missions;
    _lastResetDate = DateTime.now();
    await _saveProgress();
    _notifyListeners();
  }

  Future<void> _loadMissions() async {
    // TODO: persist mission state to prefs so progress survives app restart
    // For now, just generate if empty
    if (_activeMissions.isEmpty) {
      await _generateDailyMissions();
    }
  }

  Future<void> _saveProgress() async {
    // TODO: serialized mission state to prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_mission_reset', _lastResetDate.millisecondsSinceEpoch);
  }

  void _notifyListeners() {
    _missionUpdateController.add(_activeMissions);
  }
}
