**Project**: `SyncCompanion`

**Purpose**
- **App summary**: SyncCompanion is a Flutter mobile app that scans for Bluetooth Low Energy (BLE) peripherals, connects to a selected device, subscribes to characteristic notifications, and displays incoming data. It also supports a foreground/background service, persists a preferred device id in `SharedPreferences`, and exposes UI controls for scanning, connecting and a "Show sync notification" foreground toggle.

**Main Functions (runtime behavior)**
- **Scan**: Start/stop BLE scans and collect `ScanResult`s for visible peripherals.
- **Connect**: Connect to a chosen BLE peripheral, request MTU, discover services and characteristics.
- **Subscribe**: Enable notifications on a data characteristic and route incoming bytes into an app-visible stream.
- **Persist**: Save the selected device identifier in `SharedPreferences` so the app can auto-reconnect or remember the last device.
- **Foreground Service**: Toggle a foreground sync notification / service so the app can keep running while syncing in background.
- **Permission & Adapter Checks**: The app verifies adapter state and requests Android location/BLE permissions as needed (some of this logic has been moved into `BluetoothService`).

**Main TODO (project-level, intended to be edited by humans only)**
- NOTE: The list below is the global, project-level TODO where the development team (humans) should add and edit items. An LLM (or automated assistant) MUST NOT modify this section  it can only read it. This file contains the authoritative human TODOs for planning and coordination.

- [ ] Conectar a Thingsboard mediante MQTT para sincronización de datos.
- [X] Leer lo que entrega el dispositivo BLE
- [ ] Descodificar los datos según el protocolo definido.
- [ ] Confirmar conexion y persistencia del dispositivo BLE preferido.
- [ ] Agrandar placeholder.png 
- [ ] Mejorar el menu de opciones.
- [X] Agregar la notificacion de sincronización en foreground service.
- [ ] Verificar modularidad y limpieza del código.

Additional objectives to align with the connectivity-stage vision:
- [ ] Implementar reconexión automática y descubrimiento continuo para identificar y conectar el dispositivo incluso si la app no ha sido abierta (mientras Bluetooth esté activado).
- [ ] Asegurar la recolección y envío de telemetría en segundo plano con cola y reintentos hasta confirmación en ThingsBoard (persistir mensajes intermedios en caso de red inestable).
- [ ] Manejar y documentar permisos/entitlements por plataforma (Android: foreground service + permisos; iOS: background modes, entitlements) necesarios para mantener el envío en background.
- [ ] Almacenar de forma segura el token/credenciales de ThingsBoard y proporcionar un mecanismo de configuración (no hardcodear credenciales en el código fuente).
- [ ] Añadir pruebas end-to-end que verifiquen descubrimiento, reconexión en background y llegada de telemetría a ThingsBoard.

(LLM/editor rule: Do not write to or change this TODO section unless explicitly authorized by a human operator.)

**Suggestions (coding-agent proposals  agents may write here)**
- **Purpose**: This section is intended for coding agents and automated assistants to propose concrete next steps, code changes, and follow-ups. Coding agents can and should add proposals here to document what they plan or have done.

- **Short-term (next 12 dev sessions)**
  - Implement `adapterState$` and `isScanning$` streams in `BluetoothService`, and expose `permissionStatuses$` so UI and other services can react without directly calling platform APIs.
  - Move debounce/timer logic for scanning entirely into `BluetoothService` (so UI only calls `startScan()`/`stopScan()` and renders the `foundDevices$` stream).
  - Add a small `status` stream or enum for `BluetoothService` to emit states like `idle`, `scanning`, `connecting`, `connected`, `error`.
  - Add a tiny EventChannel ACK handshake so Flutter can confirm successful EventChannel attachment:
    - Flutter should send a one-shot ACK (via MethodChannel or a reserved EventChannel reply) after it processes the immediate status message. Native can use this ACK to confirm delivery and optionally clear or mark `lastBytes` as delivered. This reduces replay ambiguity and provides a simple handshake.

- **Medium-term (cross-cutting)**
  - Add unit tests using a mocked BLE plugin (or abstract BLE client interface) to validate reconnection, characteristic subscription, and persistence behavior.
  - Create a lightweight `SyncRelayService` interface for future cloud sync, allowing the app to queue and stream outgoing/incoming messages for a device. Keep the BLE service decoupled behind an interface so it can be mocked during integration tests.

- **Operational / Devops**
  - Re-enable `flutter_lints` and fix lint issues; add `analysis_options.yaml` consistent with team preferences.
  - Add GitHub Actions workflow to run `flutter analyze` and `flutter test` on PRs; optionally add `flutter format` check.

**Notes**
- **Where to look**: BLE and platform-related logic lives in `lib/services/bluetooth_service.dart` (service) and `lib/screens/home_page.dart` (UI). The `BluetoothService` currently exposes streams: `foundDevices$`, `connectedDevice$`, `incomingData$`, and `userAction$` (service -> UI event prompts).
- **Runtime check done**: I ran the app on a connected Android device and captured runtime logs; the app starts, requests scans, connects to a device, configures MTU and subscribes to characteristics. Connection/disconnection and scan logs are present in the device log.

**How agents should use this file**
- Coding agents should write actionable proposals and short implementation notes to the **Suggestions** section so humans can review and accept them.

---

## Suggestions

### Low-Latency Game Input Hook

**Context**: For future game integration, the current `incomingRaw$` stream is sufficient for UI display but introduces overhead (string conversion, widget rebuilds). For millisecond-level game input, consider adding a lightweight in-memory callback interface.

**Proposal**:
- Add a `registerRawCallback(void Function(List<int> bytes) callback)` method to `BluetoothService`.
- Call the callback directly from the characteristic listener before any stream processing.
- Decode the 12-byte IMU payload (6 × int16 little-endian) into floats using the scaling factors from the device code:
  - Accelerometer (ax, ay, az): divide by 100.0
  - Gyroscope (gx, gy, gz): divide by 10.0
- This avoids UI rebuild overhead and provides raw sensor data at device sampling rate (~20Hz based on 50ms delay in device code).

**Implementation Note**: Add callback registration/unregistration methods and invoke callback in the characteristic `lastValueStream.listen` handler before publishing to streams.
- Agents must not edit the **Main TODO** section unless a human asks them to.

---
Generated on: 2025-11-20
Generated by: coding agent (updated runtime logs captured).
