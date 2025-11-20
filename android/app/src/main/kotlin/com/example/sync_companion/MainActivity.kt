package com.example.sync_companion

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.Manifest
import android.bluetooth.BluetoothAdapter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
				else -> result.notImplemented()
			}
		}
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
