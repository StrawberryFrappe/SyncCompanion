import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_event.dart';
import 'event_queue.dart';

/// Service for sending events to ThingsBoard cloud.
/// Events are queued locally and flushed when connectivity is available.
class CloudService {
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  final EventQueue _queue = EventQueue();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Configurable cloud settings (can be changed in Advanced Settings)
  String _baseUrl = '';
  String _deviceToken = '';
  
  // Preference keys
  static const String _prefKeyBaseUrl = 'cloud_base_url';
  static const String _prefKeyDeviceToken = 'cloud_device_token';

  bool _isInitialized = false;
  bool _isFlushing = false;

  /// Get current base URL
  String get baseUrl => _baseUrl;

  /// Get current device token
  String get deviceToken => _deviceToken;

  /// Get current endpoint URL (full URL for display)
  String get endpointUrl => '$_baseUrl/api/v1/$_deviceToken/telemetry';

  /// Initialize the cloud service
  Future<void> init() async {
    if (_isInitialized) return;

    await _loadConfig();
    await _queue.init();

    // Listen for connectivity changes to auto-flush
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Attempt initial flush logic only if configured
    if (_isConfigured) {
      await flushQueue();
    }

    _isInitialized = true;
  }

  /// Check if cloud service is configured with valid credentials
  bool get _isConfigured => _baseUrl.isNotEmpty && _deviceToken.isNotEmpty;

  /// Load configuration from shared preferences
  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefKeyBaseUrl) ?? '';
    _deviceToken = prefs.getString(_prefKeyDeviceToken) ?? '';
  }

  /// Update cloud configuration
  Future<void> updateConfig({String? baseUrl, String? deviceToken}) async {
    final prefs = await SharedPreferences.getInstance();
    if (baseUrl != null) {
      _baseUrl = baseUrl;
      await prefs.setString(_prefKeyBaseUrl, baseUrl);
    }
    if (deviceToken != null) {
      _deviceToken = deviceToken;
      await prefs.setString(_prefKeyDeviceToken, deviceToken);
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    final hasConnection = result != ConnectivityResult.none;
    if (hasConnection && !_queue.isEmpty && _isConfigured) {
      flushQueue();
    }
  }

  /// Log an event to be sent to the cloud
  Future<void> logEvent(String eventType, Map<String, dynamic> payload) async {
    // silently ignore if not configured
    if (!_isConfigured) return;

    final event = CloudEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      eventType: eventType,
      payload: payload,
    );

    await _queue.enqueue(event);

    // Try to flush immediately if we have connectivity
    final connectivity = await _connectivity.checkConnectivity();
    final hasConnection = connectivity != ConnectivityResult.none;
    if (hasConnection) {
      flushQueue();
    }
  }

  /// Convenience methods for common event types
  Future<void> logSyncSession({
    required Duration duration,
    required DateTime startTime,
  }) async {
    await logEvent('sync_session', {
      'duration_seconds': duration.inSeconds,
      'start_time': startTime.toIso8601String(),
    });
  }

  /// Report sync status at minute boundary (new telemetry format)
  /// 
  /// For MAX30100 devices: provide avgBpm and avgSpo2
  /// For GY906 devices: provide avgTemp
  /// Vitals are wrapped in a 'vitals' object for consistent cloud parsing.
  Future<void> logSyncStatus({
    required DateTime timestamp,
    required bool synced,
    int? avgBpm,
    int? avgSpo2,
    double? avgTemp,
  }) async {
    // Build vitals object based on which readings are available
    final Map<String, dynamic> vitals = {};
    if (avgBpm != null && avgBpm > 0) {
      vitals['avgBpm'] = avgBpm;
    }
    if (avgSpo2 != null && avgSpo2 > 0) {
      vitals['avgSpo2'] = avgSpo2;
    }
    if (avgTemp != null) {
      vitals['avgTemp'] = (avgTemp * 10).round() / 10;
    }
    
    await logEvent('sync_status', {
      'timestamp': timestamp.toIso8601String(),
      'synced': synced,
      'vitals': vitals,
    });
  }

  /// Report mission completion
  Future<void> logMissionCompleted({
    required DateTime timestamp,
    required String missionId,
  }) async {
    await logEvent('mission_completed', {
      'timestamp': timestamp.toIso8601String(),
      'mission_id': missionId,
    });
  }

  Future<void> logMinigamePlayed({
    required String gameId,
    required int score,
    required Duration playTime,
  }) async {
    await logEvent('minigame_played', {
      'game_id': gameId,
      'score': score,
      'play_time_seconds': playTime.inSeconds,
    });
  }

  /// Flush all queued events to the cloud
  Future<void> flushQueue() async {
    if (_isFlushing || _queue.isEmpty || !_isConfigured) return;
    _isFlushing = true;

    try {
      final events = _queue.getAll();
      final keysToRemove = <dynamic>[];

      for (final event in events) {
        final success = await _sendEvent(event);
        if (success) {
          keysToRemove.add(event.key);
        } else {
          // Increment retry count
          event.retryCount++;
          if (event.retryCount >= 5) {
            // Drop after 5 failed attempts
            keysToRemove.add(event.key);
            print('CloudService: Dropping event ${event.id} after 5 retries');
          } else {
            await event.save();
          }
          // Stop on first failure to preserve order
          break;
        }
      }

      if (keysToRemove.isNotEmpty) {
        await _queue.removeAll(keysToRemove);
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// Send a single event to ThingsBoard
  Future<bool> _sendEvent(CloudEvent event) async {
    if (!_isConfigured) return false;
    
    try {
      // ThingsBoard telemetry API format
      final url = Uri.parse('$_baseUrl/api/v1/$_deviceToken/telemetry');
      final eventData = {
        'event_type': event.eventType,
        ...event.payload,
      };
      
      // Use 'mission' key for mission events, 'telemetry' for others
      final key = event.eventType == 'mission_completed' ? 'mission' : 'telemetry';
      
      final body = jsonEncode({
        'ts': event.timestamp.millisecondsSinceEpoch,
        'values': {
          key: jsonEncode(eventData),
        },
      });

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('CloudService: Sent event ${event.eventType}');
        return true;
      } else {
        print('CloudService: Failed to send event: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('CloudService: Error sending event: $e');
      return false;
    }
  }

  /// Get current queue size (for debugging/UI)
  int get pendingEventCount => _queue.count;

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
