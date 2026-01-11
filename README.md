# Therapets (Sync Companion)

A Flutter-based virtual pet app that uses a custom BLE hardware companion (M5-IMU-Sensor) to bring your pet to life through motion controls and real-time telemetry.

## Architecture

```mermaid
classDiagram
    %% Core Services
    class BluetoothService {
        +init()
        +connect(device)
        +startScan()
        +incomingRaw$ : Stream
        -_platform : MethodChannel
    }

    class DeviceService {
        +init()
        +events$ : Stream<DeviceEvent>
        +telemetry$ : Stream<TelemetryData>
        +updateShakeThreshold(val)
        -_checkForHighLevelEvents(data)
    }

    class DeviceEvent
    class ShakeEvent
    DeviceEvent <|-- ShakeEvent

    class TelemetryData {
        +double ax, ay, az
        +double gx, gy, gz
        +double magnitude
        +fromBytes(List<int>)
    }

    %% Service Relationships
    DeviceService --> BluetoothService : consumes
    DeviceService ..> DeviceEvent : emits
    DeviceService ..> TelemetryData : emits

    %% Game Layer
    class FlameGame
    
    class VirtualPetGame {
        +Pet currentPet
        +setSyncStatus(bool)
        +feedPet()
    }
    
    class Pet {
        <<Abstract>>
        +PetStats stats
        +BodyType bodyType
        +eat(food)
        +update(dt)
    }
    
    class BobTheBlob
    
    class PetStats {
        +double hunger
        +double happiness
        +double wellbeing
        +int gold
        +int silver
        +update(dt)
        +saveToPrefs()
    }

    class FlappyBirdGame {
        +DeviceService deviceService
        +PetStats petStats
        -onDeviceEvent(event)
    }

    class OrchestraGame {
        +DeviceService deviceService
        +List~PetMusician~ musicians
        +TonePlayer audio
        -onTelemetry(data)
    }

    %% Game Relationships
    VirtualPetGame --|> FlameGame
    FlappyBirdGame --|> FlameGame
    OrchestraGame --|> FlameGame

    VirtualPetGame --> Pet : manages
    Pet <|-- BobTheBlob
    Pet --> PetStats : has state
    
    FlappyBirdGame --> DeviceService : listens to (events$)
    FlappyBirdGame --> PetStats : awards coins to

    OrchestraGame --> DeviceService : listens to (telemetry$)
    OrchestraGame --> PetStats : references
```

### Service Layer
| Service | Role | Output |
|---------|------|--------|
| `BluetoothService` | Low-level BLE manager (scan, connect, foreground service) | `incomingRaw$` (bytes) |
| `DeviceService` | High-level abstraction (parses bytes, detects gestures) | `telemetry$` (sensor data), `events$` (ShakeEvent, etc.) |

### Game Layer (Flame Engine)
| Component | Description |
|-----------|-------------|
| `VirtualPetGame` | Main screen. Renders the pet (`BobTheBlob`) and manages sync status. |
| `Pet` / `PetStats` | Tamagotchi-style logic: hunger, happiness, currency, persistence. |
| `FlappyBirdGame` | Action game. Listens to **discrete events** (`ShakeEvent`) to jump. Awards Silver coins. |
| `OrchestraGame` | Creative tool. Listens to **continuous telemetry** to map tilt to pitch/volume. |

## Project Structure
```
lib/
├── main.dart               # App entry point
├── services/
│   ├── bluetooth_service.dart   # Low-level BLE
│   └── device_service.dart      # High-level device abstraction
├── game/
│   ├── virtual_pet_game.dart    # Main pet game
│   ├── bob_the_blob.dart        # Pet implementation
│   ├── pets/                    # Pet base classes & stats
│   └── minigames/
│       ├── flappy_bird/         # Flappy Bird minigame
│       └── orchestra/           # Pet Orchestra minigame
└── screens/                     # Flutter UI screens
```

## Quick Start
```powershell
flutter pub get
flutter run -d <device-id>
```

## Development Status

### Current Stage: Stage 3 — Telemetry Minigames
- [x] Game Framework (modular minigame screens)
- [x] Input Hook (low-latency sensor data binding)
- [x] Flappy Bird (shake to jump)
- [x] Pet Orchestra (tilt to conduct)

### Stage History
| Stage | Focus | Status |
|-------|-------|--------|
| 1 | **Connectivity** — Background BLE stability | ✅ Complete |
| 2 | **Virtual Pet Base** — Hunger, Happiness, Currency | ✅ Complete |
| 3 | **Telemetry Minigames** — Motion-controlled games | 🚧 In Progress |
