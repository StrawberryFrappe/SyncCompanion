package com.strawberryFrappe.sync_companion

import android.app.Service
import android.content.Intent
import android.content.Context
import android.os.IBinder
import android.os.Build
import android.app.NotificationManager
import android.app.NotificationChannel
import androidx.core.app.NotificationCompat
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothDevice
import android.content.SharedPreferences
import android.preference.PreferenceManager
import android.util.Log
import android.util.Base64
import android.os.Handler
import android.os.Looper

class BleForegroundService : Service() {
    companion object {
        const val ACTION_CONNECT = "ACTION_CONNECT"
        const val ACTION_DISCONNECT = "ACTION_DISCONNECT"
        const val ACTION_UPDATE_NOTIFICATION = "ACTION_UPDATE_NOTIFICATION"
        const val ACTION_QUERY_STATUS = "ACTION_QUERY_STATUS"
        const val PREF_SAVED_ID = "saved_device_id"
        const val PREF_CONNECTED = "native_connected"
        const val PREF_LAST_BYTES = "last_bytes_b64"
        const val CHANNEL_ID = "sync_companion_native"
        val TARGET_CHAR = java.util.UUID.fromString("04933a4f-756a-4801-9823-7b199fe93b5e")
        val CCC_UUID = java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        // Set to true when debugging raw notify payloads; keep false for normal runs.
        const val DATA_LOG = false
    }

    private var adapter: BluetoothAdapter? = null
    private var gatt: BluetoothGatt? = null
    private var connectedDeviceId: String? = null
    private var prefs: SharedPreferences? = null
    private var lastBytes: ByteArray? = null
    private val handler = Handler(Looper.getMainLooper())
    private var reconnectAttempts = 0
    // awaiting ACK from Dart when we emit cached status/lastBytes
    private var awaitingAck: Boolean = false
    private var ackClearRunnable: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        prefs = PreferenceManager.getDefaultSharedPreferences(this)
        adapter = BluetoothAdapter.getDefaultAdapter()
        createNotificationChannel()
        startForeground(2001, buildNotification("Initializing BLE service"))
        // Do not clear the persisted connected flag here — keep the last known
        // native state so UI can display it immediately. The service will update
        // the persisted flag when a real connection/disconnection occurs.
        // If saved device id exists, attempt reconnect
        val did = prefs?.getString(PREF_SAVED_ID, null)
        if (did != null) {
            handler.postDelayed({ connectToDevice(did) }, 2000)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val action = intent?.action
            when (action) {
                ACTION_CONNECT -> {
                    val id = intent?.getStringExtra("id")
                    if (id != null) connectToDevice(id)
                }
                ACTION_DISCONNECT -> disconnectGatt()
                ACTION_UPDATE_NOTIFICATION -> updateNotificationForData()
                ACTION_QUERY_STATUS -> {
                    // Reply with canonical persisted connected state and emit lastBytes
                    val connectedNow = prefs?.getString(PREF_SAVED_ID, null) != null
                        try { Log.i("BleForegroundService", "query status: connected=$connectedNow lastBytesLen=${lastBytes?.size ?: 0}") } catch (e: Exception) {}
                        sendStatusBroadcast(connectedNow)
                        try {
                            if (lastBytes != null) {
                                val bcast = Intent("com.strawberryFrappe.sync_companion.BLE_EVENT")
                                bcast.setPackage("com.strawberryFrappe.sync_companion")
                                bcast.putExtra("data", lastBytes)
                                sendBroadcast(bcast)
                            }
                            // Start short awaiting-ACK window so Dart can ack receipt if desired
                            try {
                                awaitingAck = true
                                ackClearRunnable?.let { handler.removeCallbacks(it) }
                                ackClearRunnable = Runnable {
                                    if (awaitingAck) {
                                        if (DATA_LOG) Log.w("BleForegroundService", "native status ack not received within timeout")
                                        awaitingAck = false
                                    }
                                }
                                handler.postDelayed(ackClearRunnable!!, 2000)
                            } catch (e: Exception) {}
                        } catch (e: Exception) {}
                }
                    "ACTION_NATIVE_ACK" -> {
                        try {
                            // Clear awaiting ACK state if matches device (deviceId optional)
                            val did = intent?.getStringExtra("deviceId")
                            val ts = intent?.getLongExtra("timestamp", 0L)
                            awaitingAck = false
                            ackClearRunnable?.let { handler.removeCallbacks(it) }
                            if (DATA_LOG) {
                                try { Log.i("BleForegroundService", "received nativeStatusAck device=$did ts=$ts") } catch (e: Exception) {}
                            }
                        } catch (e: Exception) {}
                    }
                else -> {
                    // plain start: attempt auto-reconnect if saved id exists
                    val did = prefs?.getString(PREF_SAVED_ID, null)
                    if (did != null && gatt == null) {
                        handler.postDelayed({ connectToDevice(did) }, 1000)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("BleForegroundService", "onStartCommand error: ${e}")
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        disconnectGatt()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            val ch = NotificationChannel(CHANNEL_ID, "Therapets", NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(text: String) = NotificationCompat.Builder(this, CHANNEL_ID)
        .setContentTitle("Therapets")
        .setContentText(text)
        .setSmallIcon(android.R.drawable.ic_dialog_info)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .build()

    private fun updateNotificationForData() {
        try {
            val showLive = prefs?.getBoolean("notif_show_data", false) ?: false
            // debug: log prefs read for tests
            try {
                if (DATA_LOG) {
                    Log.i("BleForegroundService", "updateNotificationForData prefs: notif_show_data=$showLive saved_id=${prefs?.getString(PREF_SAVED_ID, null)} connected=${prefs?.getBoolean(PREF_CONNECTED, false)}")
                }
            } catch (e: Exception) {}
            val text = if (showLive && lastBytes != null) {
                // show a short hex preview
                val hex = lastBytes!!.joinToString(" ") { String.format("%02x", it) }
                if (hex.length > 120) hex.substring(0, 120) + "..." else hex
            } else {
                "Your device is synced"
            }
            try {
                val nm = getSystemService(NotificationManager::class.java)
                nm.notify(2001, buildNotification(text))
                if (DATA_LOG) try { Log.i("BleForegroundService", "notify(notificationId=2001) used for data update") } catch (e: Exception) {}
            } catch (e: Exception) {}
        } catch (e: Exception) { }
    }

    private fun connectToDevice(id: String) {
        try {
            if (adapter == null) return
            if (gatt != null) {
                disconnectGatt()
            }
            val device: BluetoothDevice = adapter!!.getRemoteDevice(id)
            connectedDeviceId = id
            // Save for reboot auto-start
            prefs?.edit()?.putString(PREF_SAVED_ID, id)?.apply()
            gatt = device.connectGatt(this, false, gattCallback)
            // update notification (use notify to change visible content; keep service foreground started in onCreate)
            try {
                val nm = getSystemService(NotificationManager::class.java)
                nm.notify(2001, buildNotification("Connecting to device"))
                if (DATA_LOG) try { Log.i("BleForegroundService", "notify(notificationId=2001) used for connecting") } catch (e: Exception) {}
            } catch (e: Exception) {}
        } catch (e: Exception) {
            // schedule reconnect
            scheduleReconnect()
        }
    }

    private fun disconnectGatt() {
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (e: Exception) {}
        gatt = null
        connectedDeviceId = null
        // clear saved id
        prefs?.edit()?.remove(PREF_SAVED_ID)?.apply()
        stopForeground(true)
        stopSelf()
    }

    private fun scheduleReconnect() {
        reconnectAttempts++
        val delay = (Math.min(30, 1 shl reconnectAttempts) * 1000).toLong()
        handler.postDelayed({
            val did = prefs?.getString(PREF_SAVED_ID, null)
            if (did != null) connectToDevice(did)
        }, delay)
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                reconnectAttempts = 0
                // persist connected state
                try { prefs?.edit()?.putBoolean(PREF_CONNECTED, true)?.apply() } catch (e: Exception) {}
                sendStatusBroadcast(true)
                try {
                    val nm = getSystemService(NotificationManager::class.java)
                    nm.notify(2001, buildNotification("Connected"))
                    if (DATA_LOG) try { Log.i("BleForegroundService", "notify(notificationId=2001) used for connected") } catch (e: Exception) {}
                } catch (e: Exception) {}
                g.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                sendStatusBroadcast(false)
                try {
                    val nm = getSystemService(NotificationManager::class.java)
                    nm.notify(2001, buildNotification("Disconnected"))
                    if (DATA_LOG) try { Log.i("BleForegroundService", "notify(notificationId=2001) used for disconnected") } catch (e: Exception) {}
                } catch (e: Exception) {}
                // try to reconnect
                g.close()
                gatt = null
                scheduleReconnect()
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            try {
                val services = g.services
                var targetChar: BluetoothGattCharacteristic? = null
                for (s in services) {
                    for (c in s.characteristics) {
                        if (c.uuid == TARGET_CHAR) {
                            targetChar = c
                            break
                        }
                    }
                    if (targetChar != null) break
                }
                if (targetChar != null) {
                    g.setCharacteristicNotification(targetChar, true)
                    val desc = targetChar.getDescriptor(CCC_UUID)
                    if (desc != null) {
                        desc.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        g.writeDescriptor(desc)
                    }
                } else {
                    // subscribe to any notify char as fallback
                    for (s in services) {
                        for (c in s.characteristics) {
                            if ((c.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) {
                                g.setCharacteristicNotification(c, true)
                                val d = c.getDescriptor(CCC_UUID)
                                if (d != null) {
                                    d.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                    g.writeDescriptor(d)
                                }
                                break
                            }
                        }
                    }
                }
            } catch (e: Exception) {}
        }

        override fun onCharacteristicChanged(g: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            try {
                val bytes = characteristic.value
                lastBytes = bytes
                // persist a short replay buffer (base64) for UI attach
                try {
                    val b64 = Base64.encodeToString(bytes, Base64.DEFAULT)
                    prefs?.edit()?.putString(PREF_LAST_BYTES, b64)?.apply()
                } catch (e: Exception) {}
                // Log raw data so it appears in logcat/terminal
                if (DATA_LOG) {
                    try {
                        val hex = bytes.joinToString(" ") { String.format("%02x", it) }
                        Log.i("BleForegroundService", "notify ${TARGET_CHAR} len=${bytes.size} hex=$hex")
                    } catch (e: Exception) {}
                }
                val bcast = Intent("com.strawberryFrappe.sync_companion.BLE_EVENT")
                bcast.setPackage("com.strawberryFrappe.sync_companion")
                bcast.putExtra("data", bytes)
                sendBroadcast(bcast)
                // When broadcasting live data, allow Dart to acknowledge receipt if desired.
                try {
                    awaitingAck = true
                    ackClearRunnable?.let { handler.removeCallbacks(it) }
                    ackClearRunnable = Runnable {
                        if (awaitingAck) {
                            if (DATA_LOG) Log.w("BleForegroundService", "live data ack not received within timeout")
                            awaitingAck = false
                        }
                    }
                    handler.postDelayed(ackClearRunnable!!, 2000)
                } catch (e: Exception) {}
                // update notification according to user preference
                updateNotificationForData()
            } catch (e: Exception) {}
        }
    }

    private fun sendStatusBroadcast(connected: Boolean) {
        val i = Intent("com.strawberryFrappe.sync_companion.BLE_STATUS")
        i.setPackage("com.strawberryFrappe.sync_companion")
        i.putExtra("connected", connected)
        try {
            // keep preferences in sync so other processes can read canonical state
            prefs?.edit()?.putBoolean(PREF_CONNECTED, connected)?.apply()
        } catch (e: Exception) {}
        sendBroadcast(i)
    }
}
