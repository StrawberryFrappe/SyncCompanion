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
}

/// Mission: Stay synced for a specific duration (in seconds).
class SyncDurationMission extends Mission {
  @override
  final String id = 'mission_sync_duration';
  
  final double targetDuration; // seconds
  double _currentDuration = 0.0;

  SyncDurationMission({
    required this.targetDuration,
    required int rewardGold,
    double rewardHappiness = 0.05,
  }) : _goldReward = rewardGold, _happinessReward = rewardHappiness;

  final int _goldReward;
  final double _happinessReward;

  @override
  int get goldReward => _goldReward;

  @override
  double get happinessReward => _happinessReward;

  @override
  String get title => 'Sync Master';

  @override
  String get description => 'Stay synced for ${(targetDuration / 60).ceil()} minutes today.';

  @override
  bool update(MissionContext ctx) {
    if (isCompleted || ctx.isDeviceSynced != true || ctx.dt == null) return false;

    _currentDuration += ctx.dt!;
    _progress = (_currentDuration / targetDuration).clamp(0.0, 1.0);
    return isCompleted;
  }
}

/// Mission: Play any minigame.
class MinigamePlayMission extends Mission {
  @override
  final String id = 'mission_minigame_play';
  
  final int targetPlays;
  int _currentPlays = 0;

  MinigamePlayMission({
    this.targetPlays = 1,
    required int rewardGold,
  }) : _goldReward = rewardGold;

  final int _goldReward;

  @override
  int get goldReward => _goldReward;

  @override
  double get happinessReward => 0.1;

  @override
  String get title => 'Game Time';

  @override
  String get description => 'Play any minigame $targetPlays time(s).';

  @override
  bool update(MissionContext ctx) {
    if (isCompleted || ctx.minigameId == null) return false;

    _currentPlays++;
    _progress = (_currentPlays / targetPlays).clamp(0.0, 1.0);
    return isCompleted;
  }
  
  @override
  void reset() {
    super.reset();
    _currentPlays = 0;
  }
}

/// Mission: Feed the pet.
class FeedPetMission extends Mission {
  @override
  final String id = 'mission_feed_pet';
  
  final int targetFeeds;
  int _currentFeeds = 0;

  FeedPetMission({
    this.targetFeeds = 3,
    required int rewardGold,
  }) : _goldReward = rewardGold;

  final int _goldReward;

  @override
  int get goldReward => _goldReward;

  @override
  double get happinessReward => 0.05;

  @override
  String get title => 'Yummy Time';

  @override
  String get description => 'Feed your pet $targetFeeds times.';

  @override
  bool update(MissionContext ctx) {
    if (isCompleted || ctx.foodId == null) return false;

    _currentFeeds++;
    _progress = (_currentFeeds / targetFeeds).clamp(0.0, 1.0);
    return isCompleted;
  }
  
  @override
  void reset() {
    super.reset();
    _currentFeeds = 0;
  }
}
