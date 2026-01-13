import 'package:flutter/foundation.dart';

/// Context passed to update missions.
class MissionContext {
  final double? dt; // Time delta in seconds
  final bool? isDeviceSynced;
  final String? minigameId;
  final int? minigameScore;
  final String? foodId; // For feeding missions
  final double? activityDistance; // For future GPS/pedometer missions

  MissionContext({
    this.dt,
    this.isDeviceSynced,
    this.minigameId,
    this.minigameScore,
    this.foodId,
    this.activityDistance,
  });
}

/// Abstract base class for all daily missions.
abstract class Mission {
  String get id;
  String get title;
  String get description;
  int get goldReward;
  double get happinessReward;

  /// 0.0 to 1.0
  double _progress = 0.0;
  double get progress => _progress;
  @protected
  set progress(double value) => _progress = value;
  bool get isCompleted => _progress >= 1.0;

  bool _isClaimed = false;
  bool get isClaimed => _isClaimed;

  /// Update mission progress based on context.
  /// Returns check if mission just completed (true only on the frame it completes).
  bool update(MissionContext ctx);

  void markClaimed() {
    _isClaimed = true;
  }

  /// Reset for a new day
  void reset() {
    _progress = 0.0;
    _isClaimed = false;
  }

  /// Serialize mission state to JSON
  Map<String, dynamic> toJson();

  /// Restore progress and claimed state from saved data
  void restoreState(double savedProgress, bool claimed) {
    _progress = savedProgress;
    _isClaimed = claimed;
  }
}


