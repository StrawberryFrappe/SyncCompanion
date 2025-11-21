package com.example.sync_companion

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
import android.os.Handler
import android.os.Looper

class BleForegroundService : Service() {
    companion object {
        const val ACTION_CONNECT = "ACTION_CONNECT"
        const val ACTION_DISCONNECT = "ACTION_DISCONNECT"
        const val ACTION_UPDATE_NOTIFICATION = "ACTION_UPDATE_NOTIFICATION"
        const val ACTION_QUERY_STATUS = "ACTION_QUERY_STATUS"
        const val PREF_SAVED_ID = "saved_device_id"
        const val CHANNEL_ID = "sync_companion_native"
        val TARGET_CHAR = java.util.UUID.fromString("04933a4f-756a-4801-9823-7b199fe93b5e")
        val CCC_UUID = java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private var adapter: BluetoothAdapter? = null
    private var gatt: BluetoothGatt? = null
    private var connectedDeviceId: String? = null
    private var prefs: SharedPreferences? = null
    private var lastBytes: ByteArray? = null
    private val handler = Handler(Looper.getMainLooper())
    private var reconnectAttempts = 0

    override fun onCreate() {
        super.onCreate()
        prefs = PreferenceManager.getDefaultSharedPreferences(this)
        adapter = BluetoothAdapter.getDefaultAdapter()
        createNotificationChannel()
        startForeground(2001, buildNotification("Initializing BLE service"))
        // If saved device id exists, attempt reconnect
        val did = prefs?.getString(PREF_SAVED_ID, null)
        if (did != null) {
            handler.postDelayed({ connectToDevice(did) }, 1000)
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
                    val connectedNow = gatt != null
                    sendStatusBroadcast(connectedNow)
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
            val ch = NotificationChannel(CHANNEL_ID, "Sync Companion (native)", NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(text: String) = NotificationCompat.Builder(this, CHANNEL_ID)
        .setContentTitle("Sync Companion")
        .setContentText(text)
        .setSmallIcon(android.R.drawable.ic_dialog_info)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .build()

    private fun updateNotificationForData() {
        try {
            val showLive = prefs?.getBoolean("notif_show_data", true) ?: true
            val text = if (showLive && lastBytes != null) {
                // show a short hex preview
                val hex = lastBytes!!.joinToString(" ") { String.format("%02x", it) }
                if (hex.length > 120) hex.substring(0, 120) + "..." else hex
            } else {
                "Your device is synced"
            }
            startForeground(2001, buildNotification(text))
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
            // update notification
            startForeground(2001, buildNotification("Connecting to device"))
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
                sendStatusBroadcast(true)
                startForeground(2001, buildNotification("Connected"))
                g.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                sendStatusBroadcast(false)
                startForeground(2001, buildNotification("Disconnected"))
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
                // Log raw data so it appears in logcat/terminal
                try {
                    val hex = bytes.joinToString(" ") { String.format("%02x", it) }
                    Log.i("BleForegroundService", "notify ${TARGET_CHAR} len=${bytes.size} hex=$hex")
                } catch (e: Exception) {}
                val bcast = Intent("com.example.sync_companion.BLE_EVENT")
                bcast.putExtra("data", bytes)
                sendBroadcast(bcast)
                // update notification according to user preference
                updateNotificationForData()
            } catch (e: Exception) {}
        }
    }

    private fun sendStatusBroadcast(connected: Boolean) {
        val i = Intent("com.example.sync_companion.BLE_STATUS")
        i.putExtra("connected", connected)
        sendBroadcast(i)
    }
}
