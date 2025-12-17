## 2025-12-17 - Package Rename & Android 16 Compatibility

- **Package renamed**: `com.example.sync_companion` → `com.strawberryFrappe.sync_companion`
- Fix: Terminal now receives continuous BLE packets (added `setPackage()` to broadcasts for Android 13+)
- Fix: Obfuscation toggle works correctly (removed separate process for service)
- Fix: No more "app keeps stopping" crashes (changed foreground service type to `dataSync`)
- Fix: Settings screen layout error corrected
- UX: Notification requires swipe to refresh (Android limitation, documented)

## Unreleased - 2025-11-20

- Fix: BLE subscription now explicitly finds IMU notify characteristic (`04933a4f-756a-4801-9823-7b199fe93b5e`) and publishes raw packets immediately to terminal.
- Perf: Scan window shortened to 7s and RSSI updates coalesced to 250ms batches to reduce UI jitter.
- Fix: Foreground notification updates are guarded; failures now attempt a native fallback (`MainActivity.updateNotification`).
- Add: Debug logging toggle at `BluetoothService.BLE_DEBUG` with extra logs for service discovery, chosen characteristic, notify packets, and reconnect attempts.
- UX: Terminal shows a "no recent packets" indicator when packets stop arriving for >2s.
- Persistence: Saved device id is used for in-process auto-reconnect on app init.
- Docs: `artifacts/IMPLEMENTATION_NOTES.md` added describing short-term persistence and long-term native service plan.
