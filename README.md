# Sync Companion — Virtual Pet Base (Stage 2)

This project is in **Stage 2** of development. The connectivity foundation (Phase 1) is complete. We are now building the **Virtual Pet** features that will visualize the user's therapy adherence.

## Current Focus: Virtual Pet
The app currently connects to the device and maintains a stable stream of sensor data. The immediate goal is to implement:
1.  **Pet Rendering**: Display a 2D/3D pet character.
2.  **Basic Stats**: Implement `Hunger` and `Happiness` stats tracked in a local state.
3.  **Interaction**: Allow feeding/petting to influence stats.

## Completion Criteria for Stage 2
- [ ] App displays a "Pet" (placeholder or asset) on the main screen.
- [ ] Pet state (Hunger/Happiness) decays over time or based on logic.
- [ ] User interactions (buttons/gestures) update the pet's state.
- [ ] State is persisted between app restarts.

## Where to look
- **Pet State & Logic**: `lib/features/pet/` (New directory to be created)
- **Main Connection Logic**: `lib/services/bluetooth_service.dart` (Stable)

## Quick Run
```powershell
flutter pub get
flutter run -d <device-id>
```

## Stage History
- **Stage 1 (Connectivity)**: Completed. Verified background BLE stability and ThingsBoard telemetry relay.
