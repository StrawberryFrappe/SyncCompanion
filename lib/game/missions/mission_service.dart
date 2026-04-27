import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'mission.dart';
import 'daily_missions.dart';
import '../pets/pet_stats.dart';
import '../../services/cloud/cloud_service.dart';

/// Service to manage daily missions.
class MissionService {
  final CloudService _cloudService;
  PetStats? _petStats;

  MissionService({required CloudService cloudService}) : _cloudService = cloudService;

  // Atomic bundle key — replaces the two individual keys above.
  static const String _bundleKey = 'mission_bundle';

  List<Mission> _activeMissions = [];
  List<Mission> get activeMissions => List.unmodifiable(_activeMissions);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Fail-safe to prevent overwriting SharedPreferences if load fails
  bool _canSave = false;

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

  late Box _box;

  /// Initialize with PetStats reference and Hive box
  Future<void> init(PetStats stats, Box box) async {
    _petStats = stats;
    _box = box;
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
    await _cloudService.logMissionCompleted(
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
      SyncDurationMission(targetDuration: 120 * 60, goldReward: 50), // 2 hours
      MinigamePlayMission(targetPlays: 3, goldReward: 30),
      FeedPetMission(targetFeeds: 3, goldReward: 20),
    ];
    
    _activeMissions = missions;
    _lastResetDate = DateTime.now();
    _isInitialized = true; // Mark as initialized before saving
    _canSave = true; // Safe to save now
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
    
    debugPrint('[MissionService] LOAD START (Hive)');
    _isLoading = true;

    try {
      if (_box.isNotEmpty) {
        final lastResetMs = _box.get('lastResetMs') as int?;
        if (lastResetMs != null) {
          _lastResetDate = DateTime.fromMillisecondsSinceEpoch(lastResetMs);
        }
        final missions = _box.get('missions') as List?;
        if (missions != null) {
          _activeMissions = List<Mission>.from(missions);
          _isInitialized = true;
          _canSave = true;
          _notifyListeners();
          debugPrint('[MissionService] LOAD SUCCESS (Hive) - ${_activeMissions.length} missions');
          return;
        }
      }

      // Legacy Migration from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
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
              debugPrint('[MissionService] LOAD - Found ${_activeMissions.length} missions in bundle (migrating)');
              _isInitialized = true;
              _canSave = true; 
              _notifyListeners();
              await save(); // Save to Hive
              return;
            }
          }
        } catch (e) {
          debugPrint('[MissionService] Bundle parse error during migration: $e');
        }
      }

      // If nothing found, generate fresh
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
    if (!_isInitialized || !_canSave) return Future.value();
    _saveLock = _saveLock.catchError((_) {}).then((_) => _doSave());
    return _saveLock;
  }

  Future<void> _doSave() async {
    debugPrint('[MissionService] SAVE START (Hive)');
    try {
      await _box.put('lastResetMs', _lastResetDate.millisecondsSinceEpoch);
      await _box.put('missions', _activeMissions);
      debugPrint('[MissionService] SAVE SUCCESS (Hive)');
    } catch (e) {
      debugPrint('[MissionService] SAVE FAILED (Hive): $e');
    }
  }

  void _notifyListeners() {
    _missionUpdateController.add(_activeMissions);
  }
}
