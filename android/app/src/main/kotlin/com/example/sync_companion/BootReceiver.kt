package com.example.sync_companion

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.preference.PreferenceManager
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            try {
                val prefs = PreferenceManager.getDefaultSharedPreferences(context)
                val did = prefs.getString(BleForegroundService.PREF_SAVED_ID, null)
                if (did != null && context != null) {
                    val svc = Intent(context, BleForegroundService::class.java)
                    ContextCompat.startForegroundService(context, svc)
                }
            } catch (e: Exception) {
                // ignore
            }
        }
    }
}
