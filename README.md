# Sync Companion — Connectivity Stage (v0.1)

This project is the early-stage implementation of a therapy companion app (the long-term vision is a Tamagotchi-like mini-game app that collects IMU data during therapy). At this stage the app's purpose is narrow and focused:

- Ensure a stable Bluetooth connection to the therapy "smartwatch" device.
- Continuously gather, decode, and reliably forward device telemetry (IMU and related sensor data) to a ThingsBoard server.

Completion criteria for this stage
- The app can identify and connect to the device automatically when Bluetooth is on — even if the app has not been opened (device discovery/advertising behavior like a smartwatch).
- Once connected, the app keeps receiving, decoding, and sending telemetry to ThingsBoard in the background.
- Background relaying only stops if the device is manually disconnected/forgotten, goes out of range or powers off, or the OS/user force-closes the app and its processes.

Where to look in this repo
- **Bluetooth & data flow**: `lib/services/bluetooth_service.dart`
- **Background/foreground handling**: `lib/foreground_handler.dart`
- **App entry**: `lib/main.dart`

Quick test / run steps (PowerShell)

```powershell
# 1) Install dependencies
flutter pub get

# 2) Run on a physical device (recommended for Bluetooth)
flutter run -d <device-id>
```

Configuration notes
- The app needs the ThingsBoard server URL and the device access token (device credentials) to send telemetry. You can provide these in the app configuration or environment constants before building/running.
- Background behavior differs by platform:
	- Android: a foreground service is required for persistent BLE + network uploads. The project uses `lib/foreground_handler.dart` to manage that lifecycle.
	- iOS: background modes and proper entitlements are required; the OS may suspend networking when the app is backgrounded unless configured.

Expected runtime behavior
- When Bluetooth is enabled on the phone and the device is powered, the app should detect and pair/connect automatically.
- After connection, incoming sensor packets are decoded and telemetry messages are posted to ThingsBoard as device telemetry.
- The connection should survive app backgrounding, and telemetry should continue to be sent until an explicit disconnect, device off/out-of-range, or force-close.

Testing & verification
- Use adb/logcat (Android) or device logs (iOS) to verify connection and telemetry send events.
- Confirm messages arrive at ThingsBoard (use the device's telemetry stream or device dashboard).

Next steps
- Add a secure configuration mechanism for the ThingsBoard token (don't hardcode in source in production).
- Harden reconnection logic and battery-friendly sampling for long-term usage.
- **[Completed]** Initial connectivity and background telemetry logic.

This concludes **Phase 1**. The project is now moving to **Phase 2: Virtual Pet Base**.

If you want, I can: run the repo locally, add a small config file for ThingsBoard credentials, or create a checklist for the remaining connectivity hardening tasks.