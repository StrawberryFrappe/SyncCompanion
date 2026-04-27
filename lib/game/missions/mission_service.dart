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
  // Atomic bundle key — replaces the two individual keys above.
  static const String _bundleKey = 'mission_bundle';

  List<Mission> _activeMissions = [];
  List<Mission> get activeMissions => List.unmodifiable(_activeMissions);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Stream for UI updates
  final _missionUpdateController = StreamController<List<Mission>>.broadcast();
  Stream<List<Mission>> get missionUpdates => _missionUpdateController.stream;

  // Stream for completion events (to show UI banners)
  final _completionController = StreamController<Mission>.broadcast();
  Stream<Mission> get missionCompletions => _completionController.stream;

  DateTime _lastResetDate = DateTime.now();

  // Save lock — serialises concurrent save calls so writes never interleave.
  Future<void> _saveLock = Future.value();

  PetStats? _petStats;

  /// Initialize with PetStats reference
  Future<void> init(PetStats stats) async {
    _petStats = stats;
    await _loadMissions();
    await _checkDailyReset();
  }

  /// Update all active missions with new context
  Future<void> update(MissionContext ctx) async {
    if (!_isInitialized) return;
    bool stateChanged = false;

    for (final mission in _activeMissions) {
      if (!mission.isCompleted) {
        final justCompleted = mission.update(ctx);
        if (justCompleted) {
          await _handleMissionCompletion(mission);
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

  Future<void> _handleMissionCompletion(Mission mission) async {
    if (_petStats != null) {
      _petStats!.applyMissionReward(mission.goldReward, mission.happinessReward);
    }
    
    // Log to cloud - await to ensure it's sent
    await CloudService().logMissionCompleted(
      timestamp: DateTime.now(),
      missionId: mission.id,
    );
    
    // Notify UI for banner
    _completionController.add(mission);
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
    debugPrint('[MissionService] Generating fresh daily missions');
    // Generate 3 random missions for the day
    final missions = <Mission>[
      SyncDurationMission(targetDuration: 120 * 60, rewardGold: 50), // 2 hours
      MinigamePlayMission(targetPlays: 3, rewardGold: 30),
      FeedPetMission(targetFeeds: 3, rewardGold: 20),
    ];
    
    _activeMissions = missions;
    _lastResetDate = DateTime.now();
    _isInitialized = true; // Mark as initialized before saving
    await _saveProgress();
    _notifyListeners();
  }

  /// Force reset daily missions (for debug/testing)
  Future<void> forceResetMissions() async {
    await _generateDailyMissions();
  }

  Future<void> _loadMissions() async {
    if (_isLoading) {
      debugPrint('[MissionService] LOAD SKIPPED - Already loading');
      return;
    }
    
    debugPrint('[MissionService] LOAD START');
    _isLoading = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Try reading the atomic bundle first.
      final bundleJson = prefs.getString(_bundleKey);
      if (bundleJson != null) {
        try {
          final bundle = jsonDecode(bundleJson) as Map<String, dynamic>;
          final lastResetMs = bundle['lastResetMs'] as int?;
          if (lastResetMs != null) {
            _lastResetDate = DateTime.fromMillisecondsSinceEpoch(lastResetMs);
          }
          final missionJson = bundle['missions'] as String?;
          if (missionJson != null) {
            final List<dynamic> missionList = jsonDecode(missionJson);
            _activeMissions = missionList
                .map((j) => _missionFromJson(j as Map<String, dynamic>))
                .whereType<Mission>()
                .toList();
            if (_activeMissions.isNotEmpty) {
              debugPrint('[MissionService] LOAD - Found ${_activeMissions.length} missions in bundle');
              _isInitialized = true;
              _notifyListeners();
              return;
            }
          }
        } catch (e, st) {
          debugPrint('[MissionService] Bundle parse error — falling back to legacy keys: $e');
        }
      }

      // Legacy key fallback (users upgrading from earlier versions).
      final lastResetMs = prefs.getInt(_lastResetKey);
      if (lastResetMs != null) {
        _lastResetDate = DateTime.fromMillisecondsSinceEpoch(lastResetMs);
      }
      final missionJson = prefs.getString(_missionDataKey);
      if (missionJson != null) {
        try {
          final List<dynamic> missionList = jsonDecode(missionJson);
          _activeMissions = missionList
              .map((j) => _missionFromJson(j as Map<String, dynamic>))
              .whereType<Mission>()
              .toList();
          if (_activeMissions.isNotEmpty) {
            debugPrint('[MissionService] LOAD - Found ${_activeMissions.length} missions in legacy keys');
            _isInitialized = true;
            _notifyListeners();
            // Migrate to bundle on next save
            await save();
            return;
          }
        } catch (e, st) {
          debugPrint('[MissionService] Legacy parse error: $e');
        }
      }

      // Nothing usable found — generate fresh missions.
      await _generateDailyMissions();
      debugPrint('[MissionService] LOAD COMPLETE - Fresh missions generated');
    } finally {
      _isLoading = false;
    }
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

  /// Public entry-point so callers (e.g. the app lifecycle handler) can
  /// explicitly flush mission state to disk without going through an update cycle.
  Future<void> save() => _enqueueSave();

  Future<void> _saveProgress() => _enqueueSave();

  /// Enqueue a save. Concurrent callers are serialised — each waits for the
  /// previous save to finish before starting its own write.
  Future<void> _enqueueSave() {
    if (!_isInitialized) return Future.value();
    _saveLock = _saveLock.catchError((_) {}).then((_) => _doSave());
    return _saveLock;
  }

  Future<void> _doSave() async {
    debugPrint('[MissionService] SAVE START');
    final prefs = await SharedPreferences.getInstance();
    // Single atomic key: both fields live or die together.
    final bundle = jsonEncode({
      'lastResetMs': _lastResetDate.millisecondsSinceEpoch,
      // Nest missions as a pre-encoded string so jsonEncode errors are isolated.
      'missions': jsonEncode(_activeMissions.map((m) => m.toJson()).toList()),
    });
    final success = await prefs.setString(_bundleKey, bundle);
    if (success) {
      debugPrint('[MissionService] SAVE SUCCESS');
    } else {
      debugPrint('[MissionService] SAVE FAILED!');
    }
  }

  void _notifyListeners() {
    _missionUpdateController.add(_activeMissions);
  }
}
