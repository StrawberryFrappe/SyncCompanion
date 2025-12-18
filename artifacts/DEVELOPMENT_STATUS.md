# Development Status: SyncCompanion

**Purpose**: A Virtual Pet companion app that uses smart watch-like BLE telemetry to verify therapy adherence. The pet thrives when the user follows their therapy routine.

---

## Development Roadmap (Phases)

**NOTE: The list below is the global, project-level TODO where the development team (humans) should add and edit items. An LLM (or automated assistant) MUST NOT modify this section unless explicitly authorized by a human operator.**

**FORMATTING NOTE: Strictly no emojis are allowed in this document.**

### Phase 1: Connection Stability (DONE)
*   **Goal**: Ensure reliable BLE connection and data reception.
*   [X] Scan, Connect, and Persist device connection.
*   [X] Foreground service for persistent connection.
*   [X] Crash-free operation and background stability.
*   [X] Receive raw data from device.

### Phase 2: Virtual Pet Base (DONE)
*   **Goal**: A simple, engaging pet to visualize the user's status.
*   [X] **Pet Model**: Render a basic 2D/3D pet character.
*   [X] **Customization**: Minimum viable "Clothes" system (e.g., hats/colors).
*   [X] **Basic Stats**: Implement 1-2 core stats (e.g., Hunger, Happiness).
*   [X] **Interaction**: Basic interactions (Feeding) to affect stats.

### Phase 3: Telemetry Minigames (NEXT UP)
*   **Goal**: Fun activities that strictly use device input (IMU/Sensor data).
*   [ ] **Game Framework**: Independent game screens.
*   [ ] **Input Hook**: Low-latency sensor data for game control (like Pou games).
*   [ ] **Game 1**: TBD (Movement based?)
*   [ ] **Game 2**: TBD

### Phase 4: Cloud Connectivity
*   **Goal**: Sync data to the cloud for deeper analysis/monitoring.
*   [ ] Connect to Thingsboard via MQTT.
*   [ ] Securely upload telemetry data.
*   [ ] **Queueing**: Offline data queueing and background retry logic.
*   [ ] **Security**: Secure storage for cloud credentials/tokens.
*   [ ] **Background**: Handle permissions/entitlements for robust background execution (Android/iOS).

### Phase 5: Evolution & Cleanup
*   **Goal**: Long-term health of the codebase.
*   [ ] Code hardening and optimization.
*   [ ] E2E testing (Discovery -> Connect -> Telemetry).
*   [ ] Continuous Discovery (connect even if app closed).

---

## Coding Agent Suggestions
*This section is for agents to propose technical implementation details. Agents should read this before maximizing context.*

### Virtual Pet Implementation
*   **State Management**: Use `Provider` or `Riverpod` for a local `PetState` object containing:
    *   `happiness` (0.0 - 1.0)
    *   `hunger` (0.0 - 1.0)
    *   `lastInteractionTime` (DateTime)
*   **Persistence**: Save this state to `SharedPreferences` on change (throttled).

### Low-Latency Game Input Hook (Detailed)
**Context**: `incomingRaw$` stream is good for UI but may have overhead for 60fps games.
**Proposal**:
1.  Add `registerRawCallback(void Function(List<int> bytes) callback)` to `BluetoothService`.
2.  Invoke this callback *directly* from the characteristic listener (before stream processing).
3.  **Decoding**: The 12-byte IMU payload consists of 6 × `int16` (little-endian):
    *   **Accelerometer**: `ax`, `ay`, `az` (divide by 100.0 for float)
    *   **Gyroscope**: `gx`, `gy`, `gz` (divide by 10.0 for float)
4.  This provides raw sensor data at the device's sampling rate (~20Hz) for smooth game control.

### Assets
*   Expand `placeholder.png`. We need a sprite sheet or individual assets for:
    *   Pet Idle
    *   Pet Eating
    *   Pet Happy/Sad

---
Generated on: 2025-12-17
Updated: Removed emojis and added formatting constraint.
