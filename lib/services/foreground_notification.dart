import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_service.dart';
import 'bluetooth_service.dart'; // For BLE_DEBUG constant

/// Subscribes to BluetoothService.incomingRaw$ and updates the
/// foreground notification text with formatted hex of the raw bytes.
class ForegroundNotificationUpdater {
  ForegroundNotificationUpdater(
    this._device, {
    this.throttleMs = 500,
    this.maxChars = 128,
    this.hexUppercase = false,
    this.delimiter = ' ',
    this.connectedOnly = true,
  });

  final DeviceService _device;
  final int throttleMs;
  final int maxChars;
  final bool hexUppercase;
  final String delimiter;
  final bool connectedOnly;

  StreamSubscription<List<int>>? _sub;
  StreamSubscription? _connSub;
  String? _lastSent;
  String? _pending;
  Timer? _throttleTimer;
  bool _running = false;
  bool _isConnected = false;
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');

  void start() {
    if (_running) return;
    _running = true;
    _connSub = _device.connectedDevice$.listen((d) {
      _isConnected = d != null;
      // If disconnected, ensure notification/service is removed
      if (!_isConnected) _removeNotificationIfNeeded();
    });
    _sub = _device.incomingRaw$.listen(_onData, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _connSub?.cancel();
    _connSub = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _running = false;
  }

  void _onData(List<int> bytes) {
    if (connectedOnly && !_isConnected) return;
    final formatted = _formatBytes(bytes);
    if (formatted == _lastSent) return;
    _pending = formatted;
    if (_throttleTimer == null) {
      // send immediately
      _sendPending();
      _throttleTimer = Timer(Duration(milliseconds: throttleMs), () {
        if (_pending != null && _pending != _lastSent) {
          _sendPending();
        }
        _throttleTimer?.cancel();
        _throttleTimer = null;
      });
    }
  }

  String _formatBytes(List<int> bytes) {
    final parts = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    var s = parts.join(delimiter);
    if (hexUppercase) s = s.toUpperCase();
    if (s.length > maxChars) {
      s = s.substring(0, maxChars - 3) + '...';
    }
    return s;
  }

  Future<void> _sendPending() async {
    // If not connected and configured to only show when connected, remove service
    if (connectedOnly && !_isConnected) {
      await _removeNotificationIfNeeded();
      return;
    }

    // Read user preference whether to show live data
    final prefs = await SharedPreferences.getInstance();
    final showData = prefs.getBool('notif_show_data') ?? false;
    final text = showData ? (_pending ?? '') : 'Your device is synced';
    _pending = null;
    _lastSent = text;
    try {
      if (BluetoothService.BLE_DEBUG) print('ForegroundNotification: updating service text: $text');
      // Prefer native service notification update when available
      try {
        final nativeRunning = await _platform.invokeMethod('isNativeServiceRunning');
        if (nativeRunning == true) {
          await _platform.invokeMethod('updateNotification', {'text': text});
          return;
        }
      } catch (_) {}
      await FlutterForegroundTask.updateService(notificationText: text);
    } catch (e) {
      if (BluetoothService.BLE_DEBUG) print('ForegroundNotification: updateService failed: $e');
      // Fallback to platform method which can try to update native notification
      try {
        await _platform.invokeMethod('updateNotification', {'text': text});
      } catch (e2) {
        if (BluetoothService.BLE_DEBUG) print('ForegroundNotification: native fallback failed: $e2');
      }
    }
  }

  Future<void> _removeNotificationIfNeeded() async {
    try {
      if (BluetoothService.BLE_DEBUG) print('ForegroundNotification: removing service/notification');
      await FlutterForegroundTask.stopService();
    } catch (e) {
      if (BluetoothService.BLE_DEBUG) print('ForegroundNotification: removeService failed: $e');
      try {
        await _platform.invokeMethod('stopNativeService');
      } catch (e2) {
        if (BluetoothService.BLE_DEBUG) print('ForegroundNotification: stopNativeService fallback failed: $e2');
      }
    }
  }
}
