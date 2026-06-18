package com.example.megaboss

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.megaboss/calls"
        private const val RC_CALL_LOG = 1001
    }

    // State for the in-flight monitoring session
    private var pendingResult: MethodChannel.Result? = null
    private var offhookSince: Long = 0L
    private var seenOffhook = false
    private var stateListener: Any? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCallMonitoring" -> {
                        // Cancel any leftover session first
                        stopMonitoring()
                        pendingResult = result
                        offhookSince = 0L
                        seenOffhook = false
                        // Request READ_CALL_LOG so queryCallLogDuration() can read
                        // accurate talk-time after the call ends (one-time dialog).
                        if (checkSelfPermission(android.Manifest.permission.READ_CALL_LOG)
                            != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(android.Manifest.permission.READ_CALL_LOG),
                                RC_CALL_LOG,
                            )
                        }
                        startMonitoring()
                        // result is completed asynchronously when the call ends
                    }
                    "cancelCallMonitoring" -> {
                        stopMonitoring()
                        val r = pendingResult
                        pendingResult = null
                        r?.success(mapOf("duration_seconds" to 0, "cancelled" to true))
                        result.success(null)
                    }
                    "wasCallInitiated" -> {
                        result.success(seenOffhook)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun startMonitoring() {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) = handleState(state)
            }
            stateListener = cb
            tm.registerTelephonyCallback(Executors.newSingleThreadExecutor(), cb)
        } else {
            val listener = object : PhoneStateListener() {
                @Deprecated("Deprecated in API 31")
                override fun onCallStateChanged(state: Int, phoneNumber: String?) =
                    handleState(state)
            }
            stateListener = listener
            @Suppress("DEPRECATION")
            tm.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
        }
    }

    private fun handleState(state: Int) {
        when (state) {
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (!seenOffhook) {
                    seenOffhook = true
                    offhookSince = System.currentTimeMillis()
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                // Ignore the initial IDLE fired at registration (before any call activity).
                if (!seenOffhook) return

                stopMonitoring()
                val r = pendingResult ?: return
                pendingResult = null

                // CallLog is written slightly after IDLE fires; wait 800 ms then read
                // the most-recent outgoing entry for accurate talk-time (not ringing+talk).
                mainHandler.postDelayed({
                    r.success(mapOf("duration_seconds" to queryCallLogDuration()))
                }, 800)
            }
        }
    }

    private fun queryCallLogDuration(): Int {
        try {
            val uri = android.provider.CallLog.Calls.CONTENT_URI
            val projection = arrayOf(
                android.provider.CallLog.Calls.DURATION,
                android.provider.CallLog.Calls.DATE,
            )
            val selection = "${android.provider.CallLog.Calls.TYPE} = ?"
            val selectionArgs = arrayOf(android.provider.CallLog.Calls.OUTGOING_TYPE.toString())
            val sortOrder = "${android.provider.CallLog.Calls.DATE} DESC"

            contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val date = cursor.getLong(
                            cursor.getColumnIndexOrThrow(android.provider.CallLog.Calls.DATE)
                        )
                        // Only accept entries written in the last 5 minutes.
                        if (System.currentTimeMillis() - date < 5 * 60 * 1000L) {
                            return cursor.getInt(
                                cursor.getColumnIndexOrThrow(android.provider.CallLog.Calls.DURATION)
                            )
                        }
                    }
                }
        } catch (_: Exception) {
            // READ_CALL_LOG permission denied or ContentResolver error — return 0.
        }
        return 0
    }

    @Suppress("DEPRECATION")
    private fun stopMonitoring() {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        when (val l = stateListener) {
            is TelephonyCallback -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    tm.unregisterTelephonyCallback(l)
                }
            }
            is PhoneStateListener -> tm.listen(l, PhoneStateListener.LISTEN_NONE)
        }
        stateListener = null
    }
}
