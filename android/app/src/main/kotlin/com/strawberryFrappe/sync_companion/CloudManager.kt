package com.strawberryFrappe.sync_companion

import android.content.Context
import android.preference.PreferenceManager
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class CloudManager(private val context: Context) {

    private val prefs = PreferenceManager.getDefaultSharedPreferences(context)
    private val QUEUE_KEY = "cloud_event_queue"

    fun logSyncStatus(synced: Boolean, avgBpm: Int?, avgSpo2: Int?, avgTemp: Double?) {
        val payload = JSONObject().apply {
            put("timestamp", java.time.Instant.now().toString())
            put("synced", synced)
            val vitals = JSONObject()
            avgBpm?.let { if (it > 0) vitals.put("avgBpm", it) }
            avgSpo2?.let { if (it > 0) vitals.put("avgSpo2", it) }
            avgTemp?.let { vitals.put("avgTemp", Math.round(it * 10) / 10.0) }
            if (vitals.length() > 0) put("vitals", vitals)
        }

        val event = JSONObject().apply {
            put("eventType", "sync_status")
            put("payload", payload)
        }

        logEvent(event)
    }

    fun logEvent(event: JSONObject) {
        queueEvent(event)
        flushQueue()
    }

    private fun queueEvent(event: JSONObject) {
        synchronized(this) {
            val queueString = prefs.getString(QUEUE_KEY, "[]")
            val queue = try { JSONArray(queueString) } catch (e: Exception) { JSONArray() }
            queue.put(event)
            prefs.edit().putString(QUEUE_KEY, queue.toString()).apply()
        }
    }

    fun flushQueue() {
        thread {
            val endpointUrl = getEndpointUrl() ?: return@thread
            
            var currentQueue: JSONArray
            synchronized(this) {
                val queueString = prefs.getString(QUEUE_KEY, "[]")
                currentQueue = try { JSONArray(queueString) } catch (e: Exception) { JSONArray() }
                if (currentQueue.length() == 0) return@thread
            }

            val remainingQueue = JSONArray()

            for (i in 0 until currentQueue.length()) {
                val event = currentQueue.getJSONObject(i)
                val success = sendPostRequest(endpointUrl, event)
                if (!success) {
                    remainingQueue.put(event)
                }
            }

            synchronized(this) {
                prefs.edit().putString(QUEUE_KEY, remainingQueue.toString()).apply()
            }
        }
    }

    private fun sendPostRequest(urlStr: String, event: JSONObject): Boolean {
        try {
            val url = URL(urlStr)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.doOutput = true
            conn.connectTimeout = 5000
            conn.readTimeout = 5000

            val payload = JSONObject().apply {
                put(event.getString("eventType"), event.getJSONObject("payload"))
            }

            OutputStreamWriter(conn.outputStream).use { it.write(payload.toString()) }

            val responseCode = conn.responseCode
            return responseCode in 200..299
        } catch (e: Exception) {
            Log.e("CloudManager", "Failed to POST: ${e.message}")
            return false
        }
    }

    private fun getEndpointUrl(): String? {
        val baseUrl = prefs.getString("cloud_base_url", "http://200.13.5.20:8080") ?: return null
        val token = prefs.getString("cloud_device_token", "") ?: return null
        if (token.isEmpty()) return null
        return "$baseUrl/api/v1/$token/telemetry"
    }
}
