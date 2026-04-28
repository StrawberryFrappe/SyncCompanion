# Therapets Guidelines

## Code Style
- Use standard Dart and Flutter formatting.
- State Management: `provider`. Use `context.read`/`context.watch` appropriately to minimize rebuilds.
- Local Storage: `hive` and `shared_preferences`.
- Network/BLE: `flutter_blue_plus` for BLE, `dio` or `http` for network.

## Architecture
- `lib/core/`: Global models, fundamental classes (`TelemetryData`, `DeviceEvent`).
- `lib/services/`: Device bridging, BLE streams (`BluetoothService`, `DeviceService`), and Cloud (`CloudService`).
- `lib/game/`: `flame` engine components (`VirtualPetGame`, `Pet`, `PetStats`).
- `lib/screens/`: UI screens.
- Separation of Concerns: Services process raw streams (`BluetoothService` -> `DeviceService`). Game layer consumes clean events.

## Build and Test
- Dependencies: `flutter pub get`
- Generate models (Hive): `flutter pub run build_runner build --delete-conflicting-outputs`
- Run tests: `flutter test`
- Build Android: `flutter build apk`

## Conventions
- Game objects (`Pet`, `BobTheBlob`) encapsulate state and behavior (e.g. `PetStats`), updated via `update(dt)`.
- Telemetry processing is event-driven; high-level events (e.g., `ShakeEvent`) derive from low-level data (`TelemetryData`).
- Do not use `permission_handler` due to Android embedding compatibility; runtime permissions trigger via platform prompts where possible.
## Unified Sync State Vision (April 2026 Audit)
The "Sync State" dictates Cloud Telemetry, UI Display, and Daily Missions. It bridges hardware limitations (IoT 10s sensor sleep cycles) and OS constraints. 

**Case 1: Bad Readings / IoT 10s Sleep Cycle**
- **Trigger**: BLE connected, `humanDetected` flips false.
- **Action**: 15-second Grace Window. Push the *last recorded state* to the history array (do not hardcode `true`, prevents corrupting history if already false).
- **Outcome**: Bridges the 10s hardware gap without dropping sync.

**Case 2: Device on Desk (No human)**
- **Trigger**: 15s Grace expires. Device still connected.
- **Action**: Push `false` to history.
- **Outcome**: UI drops to "connected". Background minute tally stops. Cloud logs pause.

**Case 3: Device Disconnects (BLE drops)**
- **Trigger**: Connection lost.
- **Action**: UI history freezes for up to 30 seconds. UI displays "waiting". If reconnects < 30s, UI history resumes exact state (barrage maintained). If > 30s, UI history wiped.
- **Critical Distinction**: Cloud/Mission history does NOT freeze. Disconnected time logs as `false` (0s synced) for telemetry and missions. We do not fake cloud data.

**Architecture Mandate**:
- Native Android foreground service (`BleForegroundService`) is the source of truth.
- Flutter `DeviceService.onAppResumed()` must NEVER nuke state. It must read canonical state from Native.
- Cloud pushes (Thingsboard HTTP) and Mission tallies should migrate to Native to survive Flutter Engine suspension.
