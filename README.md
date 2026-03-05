# Therapets (Sync Companion)

[![Download Latest APK](https://img.shields.io/badge/Download-Android%20APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/StrawberryFrappe/SyncCompanion/releases/latest/download/app-release.apk)

A Flutter-based virtual pet app that uses a custom BLE hardware companion (M5-IMU-Sensor) to bring your pet to life through motion controls and real-time telemetry.

**Supports two hardware variants:**
- **MAX30100**: Pulse Oximeter + IMU
- **GY906**: IR Temperature Sensor + IMU

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

    %% Cloud Layer
    class CloudService {
        +init()
        +logEvent(type, payload)
        +flushQueue()
    }

    class TelemetryTracker {
        +init()
        -_onMinuteBoundary()
    }

    TelemetryTracker --> DeviceService : observes
    TelemetryTracker --> CloudService : reports to

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
| `CloudService` | Cloud connectivity & event queueing (ThingsBoard) | HTTP Telemetry |
| `TelemetryTracker` | Aggregates data & tracks sessions | `sync_status`, `mission_completed` events |

### Game Layer (Flame Engine)
| Component | Description |
|-----------|-------------|
| `VirtualPetGame` | Main screen. Renders the pet (`BobTheBlob`) and manages sync status. |
| `Pet` / `PetStats` | Tamagotchi-style logic: hunger, happiness, currency, persistence. |
| `FlappyBirdGame` | Action game. Listens to **discrete events** (`ShakeEvent`) to jump. Awards Silver coins. |
| `OrchestraGame` | Creative tool. Listens to **continuous telemetry** to map tilt to pitch/volume. |

### Supported Devices
The app automatically detects the connected device type based on the BLE packet size (Sticky detection):

| Device Variant | Sensor | Packet Size | Features |
|----------------|--------|-------------|----------|
| **MAX30100** | Pulse Oximeter | 16 bytes | BPM, SpO2, Heartbeat Waveform |
| **GY906** | IR Thermometer | 14 bytes | Body Temperature, Trend Waveform |

*Both variants include 6-axis IMU data (Accelerometer + Gyroscope).*

## Project Structure
```
lib/
├── main.dart               # App entry point
├── services/
├── services/
│   ├── bluetooth_service.dart   # Low-level BLE
│   ├── device_service.dart      # High-level device abstraction
│   └── cloud/                   # Cloud connectivity
│       ├── cloud_service.dart   # ThingsBoard API
│       └── telemetry_tracker.dart # Session tracking
├── game/
│   ├── virtual_pet_game.dart    # Main pet game
│   ├── bob_the_blob.dart        # Pet implementation
│   ├── pets/                    # Pet base classes & stats
│   └── minigames/
│       ├── flappy_bird/         # Flappy Bird minigame
│       └── orchestra/           # Pet Orchestra minigame
└── screens/                     # Flutter UI screens
    ├── pulse_oximeter/          # MAX30100 UI
    └── temperature_sensor/      # GY906 UI
```

## Quick Start
```powershell
flutter pub get
flutter run -d <device-id>
```

## Development Status

### Current Stage: Stage 5 — Multilingual Support
*Objective: Add Spanish as a supported language. The app must recognize the device's system language to adapt itself accordingly.*

### Stage History
| Stage | Focus | Status |
|-------|-------|--------|
| 1 | **Connectivity** — Background BLE stability | ✅ Complete |
| 2 | **Virtual Pet Base** — Hunger, Happiness, Currency | ✅ Complete |
| 3 | **Telemetry Minigames** — Motion-controlled games | ✅ Accomplished |
| 4 | **Cloud Connectivity** — Mission system + cloud sync | ✅ Accomplished |
| 5 | **Multilingual Support** — Adding Spanish and system language recognition | 🚧 In Progress |

## Configuration

To enable cloud telemetry:
1. Go to **Settings** > **Advanced Settings**.
2. Enter your **Cloud Base URL** (e.g., `http://YOUR_THINGSBOARD_IP:8080`).
3. Enter your **Device Token**.
4. The app will automatically start queuing and sending data when connected.
