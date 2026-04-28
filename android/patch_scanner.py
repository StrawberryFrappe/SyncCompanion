import os
import re

file_path = "app/src/main/kotlin/com/strawberryFrappe/sync_companion/BleForegroundService.kt"
with open(file_path, "r") as f:
    content = f.read()

# Add imports for scanner
if "android.bluetooth.le.ScanCallback" not in content:
    content = content.replace("import android.bluetooth.BluetoothDevice", "import android.bluetooth.BluetoothDevice\nimport android.bluetooth.le.ScanCallback\nimport android.bluetooth.le.ScanResult")

# Replace scheduleReconnect
scanner_code = """
    private var isScanning = false

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.device?.address?.let { address ->
                val targetId = prefs?.getString(PREF_SAVED_ID, null)
                if (targetId == address) {
                    try { adapter?.bluetoothLeScanner?.stopScan(this) } catch (e: Exception) {}
                    isScanning = false
                    connectToDevice(targetId)
                }
            }
        }
        override fun onScanFailed(errorCode: Int) {
            isScanning = false
        }
    }

    private fun scheduleReconnect() {
        val targetId = prefs?.getString(PREF_SAVED_ID, null) ?: return
        if (isScanning) return
        
        try {
            val scanner = adapter?.bluetoothLeScanner
            if (scanner != null) {
                isScanning = true
                scanner.startScan(scanCallback)
            } else {
                // Fallback if scanner unavailable
                reconnectAttempts++
                val delay = (Math.min(30, 1 shl reconnectAttempts) * 1000).toLong()
                handler.postDelayed({
                    val did = prefs?.getString(PREF_SAVED_ID, null)
                    if (did != null) connectToDevice(did)
                }, delay)
            }
        } catch (e: Exception) {
            isScanning = false
            reconnectAttempts++
            val delay = (Math.min(30, 1 shl reconnectAttempts) * 1000).toLong()
            handler.postDelayed({
                val did = prefs?.getString(PREF_SAVED_ID, null)
                if (did != null) connectToDevice(did)
            }, delay)
        }
    }
"""

content = re.sub(r'    private fun scheduleReconnect\(\) \{[\s\S]*?    private val gattCallback = object : BluetoothGattCallback\(\) \{', scanner_code + "\n    private val gattCallback = object : BluetoothGattCallback() {", content)

with open(file_path, "w") as f:
    f.write(content)
