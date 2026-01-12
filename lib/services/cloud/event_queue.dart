import 'package:hive/hive.dart';
import 'cloud_event.dart';

/// Persistent queue for cloud events using Hive.
class EventQueue {
  static const String _boxName = 'eventQueue';
  Box<CloudEvent>? _box;

  /// Initialize the queue (must be called after Hive.init)
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CloudEventAdapter());
    }
    _box = await Hive.openBox<CloudEvent>(_boxName);
  }

  /// Add an event to the queue
  Future<void> enqueue(CloudEvent event) async {
    await _box?.add(event);
  }

  /// Get all pending events (oldest first)
  List<CloudEvent> getAll() {
    return _box?.values.toList() ?? [];
  }

  /// Remove an event from the queue by key
  Future<void> remove(dynamic key) async {
    await _box?.delete(key);
  }

  /// Remove multiple events by their keys
  Future<void> removeAll(Iterable<dynamic> keys) async {
    await _box?.deleteAll(keys);
  }

  /// Get the number of pending events
  int get count => _box?.length ?? 0;

  /// Check if queue is empty
  bool get isEmpty => count == 0;

  /// Clear all events (use with caution)
  Future<void> clear() async {
    await _box?.clear();
  }
}
