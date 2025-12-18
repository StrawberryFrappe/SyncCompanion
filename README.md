# Sync Companion — Telemetry Minigames (Stage 3)

This project is in **Stage 3** of development. The Virtual Pet base (Stage 2) is complete. We are now building the **Telemetry Minigames** that will use device sensor data for interaction.

## Current Focus: Minigames
The app now has a connecting pet. The immediate goal is to implement:
1.  **Game Framework**: Modular minigame screens.
2.  **Input Hook**: Low-latency sensor data binding.
3.  **Games**: Implement 1-2 simple games (e.g., Infinite Jumper) controlled by the device.

## Completion Criteria for Stage 3
- [ ] Users can launch a separate Minigame screen.
- [ ] Game responds to real-time device movement (IMU).
- [ ] Game scores are tracked/displayed.

## Where to look
- **Games**: `lib/features/minigames/` (New directory)
- **Input Logic**: `lib/services/input_service.dart` (To be created)
- **Pet State**: `lib/features/pet/` (Stable)

## Quick Run
```powershell
flutter pub get
flutter run -d <device-id>
```

## Stage History
- **Stage 2 (Virtual Pet Base)**: Completed. Implemented basic pet rendering, stats (hunger/happiness), and interaction.
- **Stage 1 (Connectivity)**: Completed. Verified background BLE stability and ThingsBoard telemetry relay.
