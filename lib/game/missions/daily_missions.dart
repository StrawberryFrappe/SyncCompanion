import 'mission.dart';

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
    progress = (_currentDuration / targetDuration).clamp(0.0, 1.0);
    return isCompleted;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'sync_duration',
    'targetDuration': targetDuration,
    'currentDuration': _currentDuration,
    'rewardGold': _goldReward,
    'rewardHappiness': _happinessReward,
    'progress': progress,
    'claimed': isClaimed,
  };

  factory SyncDurationMission.fromJson(Map<String, dynamic> json) {
    final mission = SyncDurationMission(
      targetDuration: (json['targetDuration'] as num).toDouble(),
      rewardGold: json['rewardGold'] as int,
      rewardHappiness: (json['rewardHappiness'] as num?)?.toDouble() ?? 0.05,
    );
    mission._currentDuration = (json['currentDuration'] as num?)?.toDouble() ?? 0.0;
    mission.restoreState(
      (json['progress'] as num?)?.toDouble() ?? 0.0,
      json['claimed'] as bool? ?? false,
    );
    return mission;
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
    progress = (_currentPlays / targetPlays).clamp(0.0, 1.0);
    return isCompleted;
  }
  
  @override
  void reset() {
    super.reset();
    _currentPlays = 0;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'minigame_play',
    'targetPlays': targetPlays,
    'currentPlays': _currentPlays,
    'rewardGold': _goldReward,
    'progress': progress,
    'claimed': isClaimed,
  };

  factory MinigamePlayMission.fromJson(Map<String, dynamic> json) {
    final mission = MinigamePlayMission(
      targetPlays: json['targetPlays'] as int,
      rewardGold: json['rewardGold'] as int,
    );
    mission._currentPlays = json['currentPlays'] as int? ?? 0;
    mission.restoreState(
      (json['progress'] as num?)?.toDouble() ?? 0.0,
      json['claimed'] as bool? ?? false,
    );
    return mission;
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
    progress = (_currentFeeds / targetFeeds).clamp(0.0, 1.0);
    return isCompleted;
  }
  
  @override
  void reset() {
    super.reset();
    _currentFeeds = 0;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'feed_pet',
    'targetFeeds': targetFeeds,
    'currentFeeds': _currentFeeds,
    'rewardGold': _goldReward,
    'progress': progress,
    'claimed': isClaimed,
  };

  factory FeedPetMission.fromJson(Map<String, dynamic> json) {
    final mission = FeedPetMission(
      targetFeeds: json['targetFeeds'] as int,
      rewardGold: json['rewardGold'] as int,
    );
    mission._currentFeeds = json['currentFeeds'] as int? ?? 0;
    mission.restoreState(
      (json['progress'] as num?)?.toDouble() ?? 0.0,
      json['claimed'] as bool? ?? false,
    );
    return mission;
  }
}
