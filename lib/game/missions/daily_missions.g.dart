// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_missions.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncDurationMissionAdapter extends TypeAdapter<SyncDurationMission> {
  @override
  final int typeId = 2;

  @override
  SyncDurationMission read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncDurationMission(
      targetDuration: fields[0] as double,
      goldReward: fields[2] as int,
      happinessReward: fields[3] as double,
    )
      .._currentDuration = fields[1] as double
      .._progress = fields[4] as double
      .._isClaimed = fields[5] as bool;
  }

  @override
  void write(BinaryWriter writer, SyncDurationMission obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.targetDuration)
      ..writeByte(1)
      ..write(obj._currentDuration)
      ..writeByte(2)
      ..write(obj.goldReward)
      ..writeByte(3)
      ..write(obj.happinessReward)
      ..writeByte(4)
      ..write(obj._progress)
      ..writeByte(5)
      ..write(obj._isClaimed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncDurationMissionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MinigamePlayMissionAdapter extends TypeAdapter<MinigamePlayMission> {
  @override
  final int typeId = 3;

  @override
  MinigamePlayMission read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MinigamePlayMission(
      targetPlays: fields[0] as int,
      goldReward: fields[2] as int,
    )
      .._currentPlays = fields[1] as int
      .._progress = fields[3] as double
      .._isClaimed = fields[4] as bool;
  }

  @override
  void write(BinaryWriter writer, MinigamePlayMission obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.targetPlays)
      ..writeByte(1)
      ..write(obj._currentPlays)
      ..writeByte(2)
      ..write(obj.goldReward)
      ..writeByte(3)
      ..write(obj._progress)
      ..writeByte(4)
      ..write(obj._isClaimed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinigamePlayMissionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FeedPetMissionAdapter extends TypeAdapter<FeedPetMission> {
  @override
  final int typeId = 4;

  @override
  FeedPetMission read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FeedPetMission(
      targetFeeds: fields[0] as int,
      goldReward: fields[2] as int,
    )
      .._currentFeeds = fields[1] as int
      .._progress = fields[3] as double
      .._isClaimed = fields[4] as bool;
  }

  @override
  void write(BinaryWriter writer, FeedPetMission obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.targetFeeds)
      ..writeByte(1)
      ..write(obj._currentFeeds)
      ..writeByte(2)
      ..write(obj.goldReward)
      ..writeByte(3)
      ..write(obj._progress)
      ..writeByte(4)
      ..write(obj._isClaimed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedPetMissionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
