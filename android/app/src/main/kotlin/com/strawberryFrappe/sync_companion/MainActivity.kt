package com.strawberryFrappe.sync_companion

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.preference.PreferenceManager
import android.util.Base64
import android.util.Log
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "sync_companion/bluetooth"
	private val REQUEST_ENABLE_BLUETOOTH = 1001
	private val REQUEST_PERMISSIONS = 1002

	private var pendingEnableResult: MethodChannel.Result? = null
	private var pendingPermResult: MethodChannel.Result? = null
	private var requestedPerms: Array<String> = arrayOf()

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"enableBluetooth" -> {
					pendingEnableResult = result
					val enableIntent = Intent(android.bluetooth.BluetoothAdapter.ACTION_REQUEST_ENABLE)
					startActivityForResult(enableIntent, REQUEST_ENABLE_BLUETOOTH)
				}
				"requestPermissions" -> {
					val sdk = Build.VERSION.SDK_INT
					val perms = mutableListOf<String>()
					if (sdk >= Build.VERSION_CODES.S) {
						perms.add(Manifest.permission.BLUETOOTH_SCAN)
						perms.add(Manifest.permission.BLUETOOTH_CONNECT)
					} else {
						perms.add(Manifest.permission.ACCESS_FINE_LOCATION)
					}
					// Android 13+ requires runtime POST_NOTIFICATIONS permission
					if (sdk >= Build.VERSION_CODES.TIRAMISU) {
						perms.add(Manifest.permission.POST_NOTIFICATIONS)
					}
					requestedPerms = perms.toTypedArray()
					val toRequest = requestedPerms.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }.toTypedArray()
					if (toRequest.isEmpty()) {
						val map = mutableMapOf<String, Boolean>()
						for (p in requestedPerms) {
							map[p] = ContextCompat.checkSelfPermission(this, p) == PackageManager.PERMISSION_GRANTED
						}
						result.success(map)
					} else {
						pendingPermResult = result
						ActivityCompat.requestPermissions(this, toRequest, REQUEST_PERMISSIONS)
					}
				}
				"isBluetoothEnabled" -> {
					val adapter = BluetoothAdapter.getDefaultAdapter()
					result.success(adapter != null && adapter.isEnabled)
				}
				"updateNotification" -> {
					try {
						val intent = Intent(this, BleForegroundService::class.java)
						intent.action = "ACTION_UPDATE_NOTIFICATION"
						ContextCompat.startForegroundService(this, intent)
						result.success(true)
					} catch (e: Exception) {
						result.error("notif_failed", e.toString(), null)
					}
				}
				"startNativeService" -> {
					try {
						val intent = Intent(this, BleForegroundService::class.java)
						ContextCompat.startForegroundService(this, intent)
						result.success(true)
					} catch (e: Exception) {
						result.error("start_failed", e.toString(), null)
					}
				}
				"stopNativeService" -> {
					try {
						val intent = Intent(this, BleForegroundService::class.java)
						stopService(intent)
						result.success(true)
					} catch (e: Exception) {
						result.error("stop_failed", e.toString(), null)
					}
				}
				"isNativeServiceRunning" -> {
					try {
						val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
						val list = am.getRunningServices(Integer.MAX_VALUE)
						val running = list.any { it.service.className == BleForegroundService::class.java.name }
						result.success(running)
					} catch (e: Exception) {
						result.success(false)
					}
				}
				"connect" -> {
					val id = call.argument<String>("id") ?: ""
					try {
						val intent = Intent(this, BleForegroundService::class.java)
						intent.action = "ACTION_CONNECT"
						intent.putExtra("id", id)
						ContextCompat.startForegroundService(this, intent)
						result.success(true)
					} catch (e: Exception) {
						result.error("connect_failed", e.toString(), null)
					}
				}
				"disconnect" -> {
					try {
						val intent = Intent(this, BleForegroundService::class.java)
						intent.action = "ACTION_DISCONNECT"
						ContextCompat.startForegroundService(this, intent)
						result.success(true)
					} catch (e: Exception) {
						result.error("disconnect_failed", e.toString(), null)
					}
				}
				"requestNativeStatus" -> {
					try {
						val intent = Intent(this, BleForegroundService::class.java)
						intent.action = "ACTION_QUERY_STATUS"
						ContextCompat.startForegroundService(this, intent)
						val prefs = PreferenceManager.getDefaultSharedPreferences(applicationContext)
						val connected = prefs.getString("saved_device_id", null) != null
						val did = prefs.getString("saved_device_id", null)
						val lastB64 = prefs.getString("last_bytes_b64", null)
						var lastList: List<Int>? = null
						if (lastB64 != null) {
							try {
								val bytes = Base64.decode(lastB64, Base64.DEFAULT)
								lastList = bytes.map { (it.toInt() and 0xFF) }
							} catch (e: Exception) { }
						}
						val map = mutableMapOf<String, Any?>()
						map["status"] = connected
						map["deviceId"] = did
						map["humanDetected"] = prefs.getBoolean("native_human_detected", false)
						map["bpm"] = prefs.getInt("last_bpm", 0)
						map["spo2"] = prefs.getInt("last_spo2", 0)
						if (lastList != null) map["lastBytes"] = lastList
						try { Log.i("MainActivity", "requestNativeStatus replying prefs status=$connected humanDetected=${map["humanDetected"]} device=$did lastBytes=${lastList?.size}") } catch (e: Exception) {}
						result.success(map)
					} catch (e: Exception) {
						result.error("request_failed", e.toString(), null)
					}
				}
				"nativeStatusAck" -> {
					try {
						val deviceId = call.argument<String>("deviceId")
						val ts = call.argument<Long>("timestamp") ?: System.currentTimeMillis()
						val intent = Intent(this, BleForegroundService::class.java)
						intent.action = "ACTION_NATIVE_ACK"
						if (deviceId != null) intent.putExtra("deviceId", deviceId)
						intent.putExtra("timestamp", ts)
						ContextCompat.startForegroundService(this, intent)
						if (BleForegroundService.DATA_LOG) try { Log.i("MainActivity", "nativeStatusAck sent device=$deviceId ts=$ts") } catch (e: Exception) {}
						result.success(true)
					} catch (e: Exception) {
						result.error("ack_failed", e.toString(), null)
					}
				}
				"setNotifShowData" -> {
					try {
						val value = call.argument<Boolean>("value") ?: true
						val prefs = PreferenceManager.getDefaultSharedPreferences(applicationContext)
						prefs.edit().putBoolean("notif_show_data", value).apply()
						// Trigger notification refresh
						val intent = Intent(this, BleForegroundService::class.java)
						intent.action = "ACTION_UPDATE_NOTIFICATION"
						ContextCompat.startForegroundService(this, intent)
						result.success(true)
					} catch (e: Exception) {
						result.error("pref_failed", e.toString(), null)
					}
				}
				"showPetAlert" -> {
					try {
						val title = call.argument<String>("title") ?: "Pet Alert"
						val message = call.argument<String>("message") ?: "Your pet needs attention!"
						
						// Create notification channel for pet alerts (Android 8+)
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							val channelId = "pet_alerts"
							val channelName = "Pet Alerts"
							val importance = NotificationManager.IMPORTANCE_HIGH
							val channel = NotificationChannel(channelId, channelName, importance).apply {
								description = "Notifications about your pet's wellbeing"
								enableVibration(true)
							}
							val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
							notificationManager.createNotificationChannel(channel)
						}
						
						// Build and show the notification
						val notification = NotificationCompat.Builder(this, "pet_alerts")
							.setSmallIcon(android.R.drawable.ic_dialog_alert)
							.setContentTitle(title)
							.setContentText(message)
							.setPriority(NotificationCompat.PRIORITY_HIGH)
							.setAutoCancel(true)
							.build()
						
						val notificationManager = NotificationManagerCompat.from(this)
						// Check notification permission on Android 13+
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
							if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
								notificationManager.notify(3001, notification)
							}
						} else {
							notificationManager.notify(3001, notification)
						}
						
						result.success(true)
					} catch (e: Exception) {
						result.error("pet_alert_failed", e.toString(), null)
					}
				}
				"requestBatteryOptimization" -> {
					try {
						val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
						if (!pm.isIgnoringBatteryOptimizations(packageName)) {
							val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
							intent.data = Uri.parse("package:$packageName")
							startActivity(intent)
							result.success(false) // requested, not yet granted
						} else {
							result.success(true) // already exempted
						}
					} catch (e: Exception) {
						result.error("battery_opt_failed", e.toString(), null)
					}
				}
				else -> result.notImplemented()
			}
		}

		// EventChannel: forward broadcasts from native service as byte[] -> List<int>
		EventChannel(flutterEngine.dartExecutor.binaryMessenger, "sync_companion/ble_events").setStreamHandler(object: EventChannel.StreamHandler {
			var receiver: BroadcastReceiver? = null
			override fun onListen(args: Any?, events: EventChannel.EventSink?) {
				try {
					val prefs = PreferenceManager.getDefaultSharedPreferences(applicationContext)
					val connected = prefs.getString("saved_device_id", null) != null
					val did = prefs.getString("saved_device_id", null)
					val lastB64 = prefs.getString("last_bytes_b64", null)
					var lastList: List<Int>? = null
					if (lastB64 != null) {
						try {
							val bytes = Base64.decode(lastB64, Base64.DEFAULT)
							lastList = bytes.map { (it.toInt() and 0xFF) }
						} catch (e: Exception) { }
					}
					val m = mutableMapOf<String, Any?>()
					m["status"] = connected
					m["deviceId"] = did
					m["humanDetected"] = prefs.getBoolean("native_human_detected", false)
					m["bpm"] = prefs.getInt("last_bpm", 0)
					m["spo2"] = prefs.getInt("last_spo2", 0)
					if (lastList != null) m["lastBytes"] = lastList
					try { Log.i("MainActivity", "onListen emitting saved status=$connected humanDetected=${m["humanDetected"]} device=$did lastBytes=${lastList?.size}") } catch (e: Exception) {}
					events?.success(m)
					try {
						val intent = Intent(this@MainActivity, BleForegroundService::class.java)
						intent.action = "ACTION_QUERY_STATUS"
						ContextCompat.startForegroundService(this@MainActivity, intent)
						try { Log.i("MainActivity", "onListen requested live status broadcast from service") } catch (e: Exception) {}
					} catch (e: Exception) {}
				} catch (e: Exception) { }
				receiver = object: BroadcastReceiver() {
					override fun onReceive(context: Context?, intent: Intent?) {
						try {
							if (intent == null) return
							when (intent.action) {
								"com.strawberryFrappe.sync_companion.BLE_EVENT" -> {
									val data = intent.getByteArrayExtra("data")
									if (data != null) {
										val list = data.map { (it.toInt() and 0xFF) }
										events?.success(mapOf("lastBytes" to list))
										try { Log.i("MainActivity", "onReceive BLE_EVENT len=${list.size}") } catch (e: Exception) {}
									}
								}
								"com.strawberryFrappe.sync_companion.BLE_STATUS" -> {
									val connected = intent.getBooleanExtra("connected", false)
									val humanDetected = intent.getBooleanExtra("humanDetected", false)
									val bpm = intent.getIntExtra("bpm", 0)
									val spo2 = intent.getIntExtra("spo2", 0)
									events?.success(mapOf(
										"status" to connected,
										"humanDetected" to humanDetected,
										"bpm" to bpm,
										"spo2" to spo2
									))
									try { Log.i("MainActivity", "onReceive BLE_STATUS status=$connected humanDetected=$humanDetected bpm=$bpm") } catch (e: Exception) {}
								}
							}
						} catch (e: Exception) { }
					}
				}
				val filter = IntentFilter()
				filter.addAction("com.strawberryFrappe.sync_companion.BLE_EVENT")
				filter.addAction("com.strawberryFrappe.sync_companion.BLE_STATUS")
				if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
					try {
						applicationContext.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
					} catch (e: NoSuchMethodError) {
						applicationContext.registerReceiver(receiver, filter)
					}
				} else {
					applicationContext.registerReceiver(receiver, filter)
				}
			}

			override fun onCancel(args: Any?) {
				if (receiver != null) {
					try { applicationContext.unregisterReceiver(receiver) } catch (e: Exception) { }
					receiver = null
				}
			}
		})
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)
		if (requestCode == REQUEST_ENABLE_BLUETOOTH) {
			val ok = resultCode == Activity.RESULT_OK
			pendingEnableResult?.success(ok)
			pendingEnableResult = null
		}
	}

	override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode == REQUEST_PERMISSIONS) {
			val map = mutableMapOf<String, Boolean>()
			for (i in permissions.indices) {
				map[permissions[i]] = grantResults.getOrNull(i) == PackageManager.PERMISSION_GRANTED
			}
			pendingPermResult?.success(map)
			pendingPermResult = null
		}
	}
}
