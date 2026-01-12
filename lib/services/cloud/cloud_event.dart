import 'package:hive/hive.dart';

part 'cloud_event.g.dart';

/// A timestamped event to be sent to the cloud.
@HiveType(typeId: 0)
class CloudEvent extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String eventType;

  @HiveField(3)
  final Map<String, dynamic> payload;

  @HiveField(4)
  int retryCount;

  CloudEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.payload,
    this.retryCount = 0,
  });

  /// Convert to JSON for HTTP payload
  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': timestamp.millisecondsSinceEpoch,
        'type': eventType,
        'payload': payload,
      };
}
