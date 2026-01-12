# Stage 4 Kickoff Report
**Date**: 2026-01-12
**Status**: Complete

## Overview
Stage 4 focused on two primary objectives:
1.  **Cloud Connectivity**: Establishing a resilient pipeline to upload telemetry and game events to Thingsboard.
2.  **Mission System**: Introducing daily engagement loops ("Missions") to reward user activity.

This report details the technical implementation, architectural decisions, and verification results.

---

## 🏗️ Cloud Infrastructure (Part A)

### Architecture
We opted for a **Store-and-Forward** architecture to ensure data reliability in offline-first scenarios (e.g., synchronization in transit).

*   **Persistence**: `Hive` (NoSQL key-value DB). Chosen for its lightweight footprint and high performance compared to SQLite.
*   **Protocol**: `HTTPS` (REST API). Chosen over MQTT for simplicity and because the phone acts as the gateway.
*   **Connectivity**: `connectivity_plus` to detect network changes.

### Components
1.  **`CloudEvent` (Model)**
    *   Stores `eventType`, `payload` (JSON), `timestamp`, and `retryCount`.
    *   Persisted efficiently using a TypeAdapter.

2.  **`EventQueue` (Service)**
    *   Manages the local Hive box (`events_queue`).
    *   Provides FIFO access to events.
    *   **Resilience**: Events persist across app restarts. Queue size is implicitly limited only by storage (though a cap could be added later).

3.  **`CloudService` (Singleton)**
    *   Orchestrates the sync process.
    *   **Auto-Flush**: Listens for `ConnectivityResult.mobile` or `wifi`. Triggers an upload batch immediately.
    *   **Retry Logic**: Failed uploads increment `retryCount`. Events > 5 retries are dead-lettered/dropped.
    *   **Batching**: Currently uploads serially to ensure order, but ready for batch API endpoints.

---

## 🎯 Mission System (Part B)

### Design
Missions are daily goals that reset automatically. They are designed to encourage:
1.  Staying synced (Device usage).
2.  Playing minigames (App engagement).
3.  Caring for the pet (Feeding).

### Components
1.  **`Mission` (Abstract Class)**
    *   Defines core properties: `id`, `title`, `goldReward`, `progress` (0.0-1.0).
    *   Subclasses:
        *   `SyncDurationMission`: Tracks time connected to BLE device.
        *   `MinigamePlayMission`: Tracks number of completed minigames.
        *   `FeedPetMission`: Tracks food items consumed.

2.  **`MissionService`**
    *   Manages the active list of missions.
    *   **Daily Reset**: Checks date on init. If a new day, regenerates missions.
    *   **Context Updates**: Accepts `MissionContext` (dt, flags) to update relevant missions.
    *   **Rewards**: Automatically adds Gold/Happiness to `PetStats` upon completion.
    *   **Notifications**: Streams completion events for UI banners.

3.  **`MissionOverlay` (UI)**
    *   **Floating Widget**: Located in the top-right HUD stack.
    *   **Expandable**: Taps to show a detailed card list of today's missions.
    *   **Visuals**: Progress bars, checkmarks, and Gold reward indicators.
    *   **Placement**: Integrated into the main HUD column for consistent layout (Settings -> Missions -> Currency).

---

## 🔄 Integration Points

*   **`GameScreen`**:
    *   Initializes `MissionService` after `PetStats` is ready.
    *   **Timer**: Calls `MissionService.update()` every second with `dt` and sync status (driving the Sync Mission).
    *   **DragTarget**: Calls `MissionService.update()` when food is dropped (driving Feed Mission).
*   **Minigame Navigation**:
    *   Updates `MissionContext` when returning from `FlappyBird`, `Orchestra`, or `Donut` screens (driving Play Mission).

## 🧪 Verification
*   **Build**: APK builds successfully (`flutter build apk --debug`).
*   **Analysis**: `flutter analyze` passes (ignoring benign deprecation warnings).
*   **Logic**:
    *   Verified `MissionService` correctly awards gold.
    *   Verified `CloudService` queues events when offline (simulated).

## 📝 Future Improvements
*   **Real Credentials**: Replace placeholder Thingsboard URL and Token with production values.
*   **Batch Upload**: Optimize HTTP requests to send multiple events in one POST.
*   **More Missions**: "Walk 1km" (Pedometer integration), "Score 50 in Flappy Bird", etc.

---

## 🗂️ Directory Refactoring (2026-01-12)

The `lib/services/` directory was reorganized for better maintainability and separation of concerns:

### New Structure
```
lib/services/
├── device/
│   ├── bluetooth_service.dart      # Low-level BLE operations
│   └── device_service.dart         # High-level device abstraction
├── cloud/
│   ├── cloud_service.dart          # Cloud sync orchestration
│   ├── cloud_event.dart            # Event model
│   ├── cloud_event.g.dart          # Generated Hive adapter
│   └── event_queue.dart            # Persistent event queue
└── notifications/
    ├── foreground_notification.dart # Foreground service notifications
    └── pet_notification_service.dart # Pet alert notifications

lib/game/missions/
├── mission.dart                    # Abstract Mission class + MissionContext
├── daily_missions.dart             # Concrete mission implementations
└── mission_service.dart            # Mission management (moved from services/)
```

### Rationale
| Directory | Purpose |
|-----------|---------|
| `device/` | All BLE/hardware communication. `DeviceService` is the public API. |
| `cloud/` | Cloud connectivity (ThingsBoard). Event queuing and HTTP sync. |
| `notifications/` | Android notifications (foreground service, pet alerts). |
| `game/missions/` | Mission logic consolidated: abstract class, implementations, and service. |

