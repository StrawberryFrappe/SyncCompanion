SyncCompanion - BLE & Foreground Improvements

Date: 2025-11-20

Summary
- Improved BLE subscription to explicitly find the IMU notify characteristic (04933a4f-756a-4801-9823-7b199fe93b5e) and publish raw bytes immediately.
- Batched scan result emissions to reduce UI jitter and shortened scan window to 7s.
- Added guarded debug logs (toggle in `BluetoothService.BLE_DEBUG`).
- Foreground notification updater now logs failures and falls back to a native `updateNotification` method on `MainActivity`.
- Auto-reconnect improved while app process exists (reads saved device id and attempts reconnect).

Short-term persistence (implemented)
- When a connection is made with `save: true`, the device id is saved to SharedPreferences under `saved_device_id`.
- On app init (`BluetoothService.init()`), the saved id is read and an _in-process_ auto-reconnect loop runs trying to find the device and connect while the app process remains alive. Backoff is simple and bounded (2s delay between attempts).
- This provides durable reconnect while the app process is running or in foreground/background with the Dart isolate alive (foreground service keeps process alive on Android).

Long-term native service (recommended)
- Implement an Android-native foreground BLE manager written in Kotlin:
  - Runs as a native Android `Service` with `startForeground()` and its own Notification channel.
  - Owns `BluetoothGatt` and `BluetoothLeScanner` so reconnects/notifications survive even when Flutter/Dart process is killed.
  - Communicates with Flutter via an `EventChannel` for packet streaming and a `MethodChannel` for control commands (connect/disconnect/updateNotification).
  - Handles runtime permissions, scan/connect backoff, and robust foreground notification updates.
- Reasons: Flutter plugins and Dart isolates can be stopped/GC'd by the OS; a native service is the only reliable way to run persistent BLE responsibilities on Android.

Suggested API surface for native service
- MethodChannel calls:
  - `startNativeBleService()`
  - `stopNativeBleService()`
  - `connectDevice(id)`
  - `disconnectDevice(id)`
  - `updateNotification({text})`
- EventChannel events:
  - `packet` {deviceId, timestamp, bytes}
  - `connection` {deviceId, status}
  - `scanResult` {deviceId, rssi, name, adv}

Feature flagging
- Implement native-service behind a compile flag or runtime switch (e.g., gradle property or runtime feature toggles) to avoid shipping incomplete behavior.

How to test (manual)
1. Build & run on Android device/emulator with BLE adapter:
   flutter run -d <device-id>
2. Monitor logs:
   adb logcat | Select-String -Pattern "04933a4f|Sync Companion|flutter_foreground_task|BLE"
3. In-app:
   - Open SETTINGS, scan for devices (scan window ~7s), tap your device.
   - Terminal should show hex IMU packets as they arrive.
   - Foreground notification should update (throttled ~500ms) with recent raw bytes.
   - If notification update fails, check native logs for `updateNotification` calls.

Notes
- The native fallback notification is implemented as a simple notification updater in `MainActivity` for robustness; the long-term native-service approach is recommended for fully durable background BLE behavior.
- Detailed implementation comments are present inline in modified Dart files.
