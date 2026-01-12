// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CloudEventAdapter extends TypeAdapter<CloudEvent> {
  @override
  final int typeId = 0;

  @override
  CloudEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CloudEvent(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      eventType: fields[2] as String,
      payload: (fields[3] as Map).cast<String, dynamic>(),
      retryCount: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CloudEvent obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.eventType)
      ..writeByte(3)
      ..write(obj.payload)
      ..writeByte(4)
      ..write(obj.retryCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
