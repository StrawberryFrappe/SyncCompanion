KNOWN ISSUES — Sync Companion
===============================

Date: 2025-11-21
Environment: Android (SM X510 tablet), Flutter app built from branch `stage-1`.

This document describes currently-observed, reproducible behaviors that are not considered bugs in urgent fix-state but are known issues with recommended workarounds and diagnostic steps.

1) Home screen shows "SEARCHING" after app kill even with active native connection
---------------------------------------------------------------------------------
Observed behavior
- If the app is killed (swipe-killed or process terminated) while the native foreground BLE service remains running in its separate process, reopening the app briefly shows the Home screen's connection indicator as "SEARCHING" (or otherwise not showing the persisted connected state). Eventually the app reconciles state (when native status arrives) but the brief UI flip is visible.

How to reproduce
- Start the app and allow it to connect to a device (native service holds the connection).
- Swipe-kill the Flutter app (leave the native foreground service running).
- Reopen the app.
- Observe the Home screen connection state: it shows searching/pending before the native status stream updates the UI.

Why this happens (root cause)
- The Flutter UI attempts to avoid showing stale states but currently defers attaching to the native EventChannel and reading SharedPreferences until `init()` runs.
- When the Flutter process restarts, there is a short window where the UI renders before the native EventChannel has emitted the persisted status or before the platform `requestNativeStatus` reply is processed.
- The native foreground service keeps the canonical state (in SharedPreferences and via BROADCAST intent), but the UI's initial optimism logic and the event attachment timing causes a transient mismatch.

Temporary workarounds
- Wait ~1-2 seconds after launching the app; the UI will reconcile automatically once the EventChannel / `requestNativeStatus` responses arrive.
- Use the Settings page to view the persisted device id (shows quickly) while the Home screen finishes updating.

Suggested fixes (engineering notes)
- Emit persisted native-connected state as early as possible during Flutter startup (attach EventChannel earlier and read SharedPreferences synchronously where possible). The codebase currently attempts this, but ensure the UI build path uses the persisted state as the initial value (instead of defaulting to `SEARCHING`).
- Keep the UI from rendering an immediate "SEARCHING" fallback while a pending native status request is in flight; show a neutral/persisted state placeholder instead.
- Consider adding a short debounce on the Home screen initial status render to wait for `requestNativeStatus` (e.g., 250–500 ms) before showing searching/error states.

Files of interest
- `lib/services/bluetooth_service.dart` (startup, `_attachNativeEventStream`, `init()` logic)
- `android/.../BleForegroundService.kt` (persisted state & broadcasts)
- `android/.../MainActivity.kt` (EventChannel onListen / `requestNativeStatus` behavior)

Priority: Medium — visible UX glitch but no functional damage; fix recommended for polished UX.


2) Settings terminal does not show raw data (or shows only the first packet)
-----------------------------------------------------------------------------
Observed behavior
- The Settings screen terminal sometimes shows "— no recent packets —" even when notifications are received by the native foreground service and the Android notification content updates accordingly.
- In earlier observations the terminal displayed the first packet received after attach but then did not update with subsequent packets.

How to reproduce
- Connect the device so the native process receives notifications (foreground service active).
- Open Settings → Connected Terminal.
- Observe terminal output while the device is sending notifications rapidly.
- Optionally, monitor the Android notification content (it updates when `onCharacteristicChanged` runs), while the terminal does not.

Why this happens (root cause)
- Two related causes were observed:
  1) Event format mismatch: native side sometimes sends data as a raw `byte[]` broadcast (received by `MainActivity` as a List<int>) and in other flows emits a Map containing `lastBytes` (for status queries). The Dart `EventChannel` handler originally only handled raw `List` events and ignored `Map['lastBytes']` payloads.
  2) UI subscription behavior: the terminal widget originally appended packets but in some flows the EventChannel map-path did not replay bytes into the `_incomingRawController`, so the terminal only saw the first packet (or none) depending on attach timing.

Temporary workarounds
- Reopen Settings after connecting — the persisted replay buffer (saved base64 in SharedPreferences by the native service) is emitted on attach and will show the most recent packet if available.
- Use adb logcat to confirm that the native service is receiving packets (look for `BleForegroundService` logs) — if notifications are logged there but not in the terminal, the issue is in the EventChannel path.

Fixes applied in codebase (current branch)
- `MainActivity.kt` was adjusted to emit BLE_EVENT payloads as `Map` entries with `lastBytes` (so `requestNativeStatus` and onListen both return a consistent shape).
- `lib/services/bluetooth_service.dart` was updated to accept either:
  - a raw `List<int>` EventChannel event (previous behavior), or
  - a `Map` event containing `lastBytes` which will be replayed into `_incomingRawController` and `_incomingController`.
- The Settings terminal (`lib/screens/settings_page.dart`) now:
  - subscribes to `incomingRaw$` and appends lines to a rolling buffer;
  - includes a debug print when a packet arrives (helpful when testing);
  - is placed below the `SCAN FOR DEVICES` control and constrained to use a large portion of vertical space so updates are visible.

Recommended next steps if issue persists
- Re-run and capture logs from both Flutter and Android to ensure the EventChannel emits repeated packet events:
  - Flutter console should show `BLE: native event received ...`, `BLE: map lastBytes len=...`, and the terminal debug prints `Terminal: received packet len=...` for each notify.
  - adb logcat filtered for `BleForegroundService` and `MainActivity` should show broadcasts and `onCharacteristicChanged` entries.
- If Android logs show repeated notifications but Flutter receives only one (or none) after the first:
  - Confirm `MainActivity`'s BroadcastReceiver is registered correctly and not being garbage-collected on hot-restart scenarios.
  - Confirm `EventChannel` is still attached (look for `BLE: attachNativeEventStream failed: ...` logs in Dart).
- If needed, add explicit sequence numbers to native broadcasts to detect dropped events in transit.

Files of interest
- `android/.../BleForegroundService.kt` (sends broadcasts on `onCharacteristicChanged`, persists `last_bytes_b64`)
- `android/.../MainActivity.kt` (EventChannel stream handler, onReceive mapping)
- `lib/services/bluetooth_service.dart` (`_attachNativeEventStream()` and `_handleNativeStatusMap()` code paths)
- `lib/screens/settings_page.dart` (ConnectedTerminal subscription and UI)

Priority: High — affects primary data visibility (terminal) while the native service is, in many cases, correctly receiving notifications.


Debug tips and commands
- From the developer machine, run Flutter with attached logs:
  ```powershell
  cd H:\SyncCompanion
  flutter run --debug
  ```
  Look for these markers in the Flutter logs:
  - `BLE: native event received type=...`
  - `BLE: map lastBytes len=...`
  - `Terminal: received packet len=... hex=...`

- To view Android native logs only:
  ```powershell
  adb logcat -s BleForegroundService MainActivity FlutterMain
  ```

- If you have a persistent reproduction, capture both log streams and the `SharedPreferences` values for `saved_device_id` and `last_bytes_b64` to share with debugging sessions.


Change history (branch: stage-1)
- 2025-11-20: Dart handler updated to replay `lastBytes` from map events.
- 2025-11-21: Settings terminal updated to append packets, expanded layout.
- 2025-12-17: Fixed 5 user-reported issues (see below).


3) Fixed issues (2025-12-17)
----------------------------

The following issues were identified and fixed across multiple sessions:

| Issue | Root Cause | Fix Applied |
|-------|------------|-------------|
| App shows "closing too much" popup | Service restarting too rapidly | Increased auto-reconnect delay to 2000ms |
| Terminal not receiving packets | Implicit broadcasts not delivered on Android 13+ | Added `setPackage()` to BLE_EVENT broadcasts |
| Obfuscate toggle not working | Service in separate process couldn't see SharedPreferences changes | Removed `android:process=":ble_service"` from manifest |
| App crash on Android 16 | `connectedDevice` foreground service type requires Bluetooth permissions first | Changed to `dataSync` service type |

**Note on notification live-update**: Android does not reliably refresh notification content visually even with `setOnlyAlertOnce(true)`. Users must swipe to refresh. This is an Android limitation, not a bug.

**Package renamed**: `com.example.sync_companion` → `com.strawberryFrappe.sync_companion`

Files modified:
- `android/app/build.gradle.kts` (package name)
- `android/app/src/main/AndroidManifest.xml` (process, service type, permissions)
- `android/app/src/main/kotlin/com/strawberryFrappe/sync_companion/*.kt` (all moved)
- `lib/services/bluetooth_service.dart` (lastBytes handling, setNotifShowData)
- `lib/screens/settings_page.dart` (button layout)
- `lib/screens/home_page.dart` (nativeStatusReceived flag)


End of document

