import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'mission.dart';
import 'daily_missions.dart';
import '../pets/pet_stats.dart';
import '../../services/cloud/cloud_service.dart';

/// Service to manage daily missions.
class MissionService {
  static final MissionService _instance = MissionService._internal();
  factory MissionService() => _instance;
  MissionService._internal();

  static const String _missionDataKey = 'daily_missions_data';
  static const String _lastResetKey = 'last_mission_reset';

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
    await _checkDailyReset();
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
      _saveProgress();
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
      SyncDurationMission(targetDuration: 10 * 60, rewardGold: 50), // 10 mins
      MinigamePlayMission(targetPlays: 3, rewardGold: 30),
      FeedPetMission(targetFeeds: 3, rewardGold: 20),
    ];
    
    _activeMissions = missions;
    _lastResetDate = DateTime.now();
    await _saveProgress();
    _notifyListeners();
  }

  /// Force reset daily missions (for debug/testing)
  Future<void> forceResetMissions() async {
    await _generateDailyMissions();
  }

  Future<void> _loadMissions() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load last reset date
    final lastResetMs = prefs.getInt(_lastResetKey);
    if (lastResetMs != null) {
      _lastResetDate = DateTime.fromMillisecondsSinceEpoch(lastResetMs);
    }
    
    // Load serialized missions
    final missionJson = prefs.getString(_missionDataKey);
    if (missionJson != null) {
      try {
        final List<dynamic> missionList = jsonDecode(missionJson);
        _activeMissions = missionList
            .map((json) => _missionFromJson(json as Map<String, dynamic>))
            .whereType<Mission>()
            .toList();
        
        if (_activeMissions.isNotEmpty) {
          _notifyListeners();
          return;
        }
      } catch (e) {
        print('[MissionService] Error loading missions: $e');
      }
    }
    
    // If we couldn't load, generate new missions
    await _generateDailyMissions();
  }

  Mission? _missionFromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'sync_duration':
        return SyncDurationMission.fromJson(json);
      case 'minigame_play':
        return MinigamePlayMission.fromJson(json);
      case 'feed_pet':
        return FeedPetMission.fromJson(json);
      default:
        print('[MissionService] Unknown mission type: $type');
        return null;
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save last reset date
    await prefs.setInt(_lastResetKey, _lastResetDate.millisecondsSinceEpoch);
    
    // Serialize and save all missions
    final missionList = _activeMissions.map((m) => m.toJson()).toList();
    await prefs.setString(_missionDataKey, jsonEncode(missionList));
  }

  void _notifyListeners() {
    _missionUpdateController.add(_activeMissions);
  }
}
