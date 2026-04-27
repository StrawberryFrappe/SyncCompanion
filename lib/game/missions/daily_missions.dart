import 'package:hive/hive.dart';
import 'mission.dart';

part 'daily_missions.g.dart';

/// Mission: Stay synced for a specific duration (in seconds).
@HiveType(typeId: 2)
class SyncDurationMission extends Mission {
  @override
  final String id = 'mission_sync_duration';
  
  @HiveField(0)
  final double targetDuration; // seconds
  @HiveField(1)
  double _currentDuration = 0.0;

  SyncDurationMission({
    @HiveField(0) required this.targetDuration,
    @HiveField(2) required this.goldReward,
    @HiveField(3) this.happinessReward = 0.05,
  });

  @override
  @HiveField(2)
  final int goldReward;
  @override
  @HiveField(3)
  final double happinessReward;
  @HiveField(4)
  double _progress = 0.0;
  @HiveField(5)
  bool _isClaimed = false;

  @override
  double get progress => _progress;
  @override
  set progress(double value) => _progress = value;
  @override
  bool get isClaimed => _isClaimed;
  @override
  void markClaimed() => _isClaimed = true;
  @override
  void reset() {
    _progress = 0.0;
    _isClaimed = false;
    _currentDuration = 0.0;
  }


  @override
  String get title => 'Sync Master';

  @override
  String get description => 'Stay synced for ${(targetDuration / 60).ceil()} minutes today.';

  @override
  num get currentValue => (_currentDuration / 60).floor();

  @override
  num get targetValue => (targetDuration / 60).ceil();

  @override
  String get valueUnit => 'min';

  @override
  bool update(MissionContext ctx) {
    if (isCompleted || ctx.isDeviceSynced != true || ctx.dt == null) return false;

    double previousDuration = _currentDuration;
    _currentDuration += ctx.dt!;
    
    int prevMinutes = (previousDuration / 60).floor();
    int currMinutes = (_currentDuration / 60).floor();
    
    if (currMinutes > prevMinutes || _currentDuration >= targetDuration) {
      if (_currentDuration >= targetDuration) {
          progress = 1.0;
      } else {
          progress = (currMinutes / targetValue).clamp(0.0, 1.0);
      }
      return isCompleted && previousDuration < targetDuration;
    }
    
    // Also handle initial state loading or restoration where it should be updated but isn't passing a minute boundary
    if (progress == 0 && _currentDuration > 0) {
      progress = (currMinutes / targetValue).clamp(0.0, 1.0);
    }

    return false;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'sync_duration',
    'targetDuration': targetDuration,
    'currentDuration': _currentDuration,
    'rewardGold': goldReward,
    'rewardHappiness': happinessReward,
    'progress': progress,
    'claimed': isClaimed,
  };

  factory SyncDurationMission.fromJson(Map<String, dynamic> json) {
    final mission = SyncDurationMission(
      targetDuration: (json['targetDuration'] as num).toDouble(),
      goldReward: json['rewardGold'] as int,
      happinessReward: (json['rewardHappiness'] as num?)?.toDouble() ?? 0.05,
    );
    mission._currentDuration = (json['currentDuration'] as num?)?.toDouble() ?? 0.0;
    mission.restoreState(
      (json['progress'] as num?)?.toDouble() ?? 0.0,
      json['claimed'] as bool? ?? false,
    );
    // Ensure progress is synced with minute logic on load
    mission.progress = (mission.currentValue / mission.targetValue).clamp(0.0, 1.0);
    return mission;
  }
}

/// Mission: Play any minigame.
@HiveType(typeId: 3)
class MinigamePlayMission extends Mission {
  @override
  final String id = 'mission_minigame_play';
  
  @HiveField(0)
  final int targetPlays;
  @HiveField(1)
  int _currentPlays = 0;

  MinigamePlayMission({
    @HiveField(0) this.targetPlays = 1,
    @HiveField(2) required this.goldReward,
  });

  @override
  @HiveField(2)
  final int goldReward;
  @HiveField(3)
  double _progress = 0.0;
  @HiveField(4)
  bool _isClaimed = false;

  @override
  double get progress => _progress;
  @override
  set progress(double value) => _progress = value;
  @override
  bool get isClaimed => _isClaimed;
  @override
  void markClaimed() => _isClaimed = true;
  @override
  void reset() {
    _progress = 0.0;
    _isClaimed = false;
    _currentPlays = 0;
  }

  @override
  double get happinessReward => 0.1;

  @override
  String get title => 'Game Time';

  @override
  String get description => 'Play any minigame $targetPlays time(s).';

  @override
  num get currentValue => _currentPlays;

  @override
  num get targetValue => targetPlays;

  @override
  bool update(MissionContext ctx) {
    if (isCompleted || ctx.minigameId == null) return false;

    _currentPlays++;
    progress = (_currentPlays / targetPlays).clamp(0.0, 1.0);
    return isCompleted;
  }
  

  @override
  Map<String, dynamic> toJson() => {
    'type': 'minigame_play',
    'targetPlays': targetPlays,
    'currentPlays': _currentPlays,
    'rewardGold': goldReward,
    'progress': progress,
    'claimed': isClaimed,
  };

  factory MinigamePlayMission.fromJson(Map<String, dynamic> json) {
    final mission = MinigamePlayMission(
      targetPlays: json['targetPlays'] as int,
      goldReward: json['rewardGold'] as int,
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
@HiveType(typeId: 4)
class FeedPetMission extends Mission {
  @override
  final String id = 'mission_feed_pet';
  
  @HiveField(0)
  final int targetFeeds;
  @HiveField(1)
  int _currentFeeds = 0;

  FeedPetMission({
    @HiveField(0) this.targetFeeds = 3,
    @HiveField(2) required this.goldReward,
  });

  @override
  @HiveField(2)
  final int goldReward;
  @HiveField(3)
  double _progress = 0.0;
  @HiveField(4)
  bool _isClaimed = false;

  @override
  double get progress => _progress;
  @override
  set progress(double value) => _progress = value;
  @override
  bool get isClaimed => _isClaimed;
  @override
  void markClaimed() => _isClaimed = true;
  @override
  void reset() {
    _progress = 0.0;
    _isClaimed = false;
    _currentFeeds = 0;
  }

  @override
  double get happinessReward => 0.05;

  @override
  String get title => 'Yummy Time';

  @override
  String get description => 'Feed your pet $targetFeeds times.';

  @override
  num get currentValue => _currentFeeds;

  @override
  num get targetValue => targetFeeds;

  @override
  bool update(MissionContext ctx) {
    if (isCompleted || ctx.foodId == null) return false;

    _currentFeeds++;
    progress = (_currentFeeds / targetFeeds).clamp(0.0, 1.0);
    return isCompleted;
  }
  

  @override
  Map<String, dynamic> toJson() => {
    'type': 'feed_pet',
    'targetFeeds': targetFeeds,
    'currentFeeds': _currentFeeds,
    'rewardGold': goldReward,
    'progress': progress,
    'claimed': isClaimed,
  };

  factory FeedPetMission.fromJson(Map<String, dynamic> json) {
    final mission = FeedPetMission(
      targetFeeds: json['targetFeeds'] as int,
      goldReward: json['rewardGold'] as int,
    );
    mission._currentFeeds = json['currentFeeds'] as int? ?? 0;
    mission.restoreState(
      (json['progress'] as num?)?.toDouble() ?? 0.0,
      json['claimed'] as bool? ?? false,
    );
    return mission;
  }
}
