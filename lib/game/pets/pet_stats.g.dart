// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pet_stats.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PetStatsAdapter extends TypeAdapter<PetStats> {
  @override
  final int typeId = 0;

  @override
  PetStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PetStats(
      hungerDecayRate: fields[3] as double,
      happinessGainRate: fields[4] as double,
      happinessDecayRate: fields[5] as double,
      lowWellbeingThreshold: fields[7] as double,
    )
      .._hunger = fields[0] as double
      .._happiness = fields[1] as double
      .._happinessBuffer = fields[2] as double
      .._lastUpdateTime = fields[6] as DateTime
      .._goldCoins = fields[8] as int
      .._silverCoins = fields[9] as int
      .._unlockedClothingIds = (fields[10] as List).cast<String>()
      .._equippedClothing = (fields[11] as Map).cast<String, String>()
      .._foodInventory = (fields[12] as Map).cast<String, int>();
  }

  @override
  void write(BinaryWriter writer, PetStats obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj._hunger)
      ..writeByte(1)
      ..write(obj._happiness)
      ..writeByte(2)
      ..write(obj._happinessBuffer)
      ..writeByte(3)
      ..write(obj.hungerDecayRate)
      ..writeByte(4)
      ..write(obj.happinessGainRate)
      ..writeByte(5)
      ..write(obj.happinessDecayRate)
      ..writeByte(6)
      ..write(obj._lastUpdateTime)
      ..writeByte(7)
      ..write(obj.lowWellbeingThreshold)
      ..writeByte(8)
      ..write(obj._goldCoins)
      ..writeByte(9)
      ..write(obj._silverCoins)
      ..writeByte(10)
      ..write(obj._unlockedClothingIds)
      ..writeByte(11)
      ..write(obj._equippedClothing)
      ..writeByte(12)
      ..write(obj._foodInventory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
