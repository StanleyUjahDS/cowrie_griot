package com.griotcowrie.griot_cowrie

import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class GriotFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        Log.i("GriotFCM", "FCM message received type=${data["type"]} callId=${data["callId"]}")
        // A caller can end/decline a call while the recipient's app is
        // backgrounded. Remove the ongoing full-screen notification rather
        // than leaving a stale ringing surface behind.
        val terminalCall = data["type"] == "call_log" ||
            data["type"] == "call_status_updated"
        if (terminalCall &&
            data["status"]?.let { it in setOf("ended", "declined", "missed", "failed") } == true) {
            val callId = data["callId"]?.takeIf { it.isNotBlank() }
            if (callId != null) {
                val notificationManager = getSystemService(NotificationManager::class.java)
                // This is the same deterministic id used by the custom
                // incoming-call notification and by flutter_callkit_incoming.
                notificationManager.cancel(callId.hashCode())
                if (data["type"] == "call_log") {
                    showTerminalCallNotification(notificationManager, data, callId)
                }
                Log.i("GriotFCM", "Cancelled native call notification callId=$callId")
            }
            return
        }
        if (data["type"] != "incoming_call") return
        val callId = data["callId"]?.takeIf { it.isNotBlank() } ?: return
        val bundle = Bundle().apply {
            putString("EXTRA_CALLKIT_ID", callId)
            putString("EXTRA_CALLKIT_NAME_CALLER", data["callerName"] ?: "Griot contact")
            putString("EXTRA_CALLKIT_APP_NAME", "Griot")
            putString("EXTRA_CALLKIT_HANDLE", data["callerHandle"] ?: data["callerName"] ?: "Griot contact")
            putInt("EXTRA_CALLKIT_TYPE", if (data["mode"] == "video") 1 else 0)
            putLong("EXTRA_CALLKIT_DURATION", 45000L)
            putString("EXTRA_CALLKIT_TEXT_ACCEPT", "Answer")
            putString("EXTRA_CALLKIT_TEXT_DECLINE", "Decline")
            putBoolean("EXTRA_CALLKIT_IS_CUSTOM_NOTIFICATION", true)
            putBoolean("EXTRA_CALLKIT_IS_CUSTOM_SMALL_EX_NOTIFICATION", true)
            putBoolean("EXTRA_CALLKIT_IS_SHOW_FULL_LOCKED_SCREEN", true)
            putBoolean("EXTRA_CALLKIT_IS_IMPORTANT", true)
            putBoolean("EXTRA_CALLKIT_IS_FULL_SCREEN", true)
            putString("EXTRA_CALLKIT_RINGTONE_PATH", "system_ringtone_default")
            putString("EXTRA_CALLKIT_INCOMING_CALL_NOTIFICATION_CHANNEL_NAME", "Incoming calls")
            putString("EXTRA_CALLKIT_MISSED_CALL_NOTIFICATION_CHANNEL_NAME", "Missed calls")
            putString("EXTRA_CALLKIT_BACKGROUND_COLOR", "#101214")
            putString("EXTRA_CALLKIT_ACTION_COLOR", "#3DBB68")
            putString("EXTRA_CALLKIT_TEXT_COLOR", "#FFFFFF")
            putSerializable("EXTRA_CALLKIT_EXTRA", HashMap(data))
            putSerializable("EXTRA_CALLKIT_HEADERS", HashMap<String, String>())
        }
        try {
            // The Flutter CallKit plugin is not guaranteed to have a live
            // singleton when Android delivers FCM to a terminated process.
            // Post a native full-screen call notification first; Android owns
            // the ringtone and launches the package call activity from its
            // permitted full-screen PendingIntent.
            showNativeIncomingCall(callId, bundle, data)
            Log.i("GriotFCM", "Native incoming-call notification posted")
        } catch (error: Exception) {
            Log.e("GriotFCM", "Unable to present incoming call", error)
        }
    }

    private fun showNativeIncomingCall(
        callId: String,
        data: Bundle,
        rawData: Map<String, String>,
    ) {
        val channelId = "griot_incoming_calls"
        val notificationManager =
            getSystemService(NotificationManager::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val ringtone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            val audio = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val channel = NotificationChannel(
                channelId,
                "Incoming calls",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Griot incoming voice and video calls"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 700, 400, 700)
                setSound(ringtone, audio)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val activityIntent = Intent().apply {
            setClassName(
                applicationContext,
                "com.hiennv.flutter_callkit_incoming.CallkitIncomingActivity",
            )
            action = "${applicationContext.packageName}.com.hiennv.flutter_callkit_incoming.ACTION_CALL_INCOMING"
            putExtra("EXTRA_CALLKIT_INCOMING_DATA", data)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            setPackage(applicationContext.packageName)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val fullScreenIntent = PendingIntent.getActivity(
            applicationContext,
            callId.hashCode(),
            activityIntent,
            flags,
        )
        val notification = NotificationCompat.Builder(applicationContext, channelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(data.getString("EXTRA_CALLKIT_NAME_CALLER", "Griot contact"))
            .setContentText(
                if (rawData["mode"] == "video") "Incoming video call" else "Incoming voice call",
            )
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setTimeoutAfter(45_000L)
            .setFullScreenIntent(fullScreenIntent, true)
            .setContentIntent(fullScreenIntent)
            .build()
        notificationManager.notify(callId.hashCode(), notification)
    }

    private fun showTerminalCallNotification(
        notificationManager: NotificationManager,
        data: Map<String, String>,
        callId: String,
    ) {
        val channelId = "griot_call_updates"
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Call updates",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Missed and ended Griot calls"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        val status = data["status"] ?: "ended"
        val mode = if (data["mode"] == "video") "Video call" else "Voice call"
        val fallbackTitle = when (status) {
            "missed" -> "Missed $mode"
            "declined" -> "Call declined"
            "failed" -> "Call failed"
            else -> "Call ended"
        }
        val title = data["title"]?.takeIf { it.isNotBlank() } ?: fallbackTitle
        val body = data["body"]?.takeIf { it.isNotBlank() } ?: when (status) {
            "missed" -> "You missed a call. Tap to view your call history."
            "declined" -> "$mode was declined."
            "failed" -> "$mode could not be completed."
            else -> "$mode has ended."
        }

        val contentIntent = Intent(applicationContext, MainActivity::class.java).apply {
            action = "${applicationContext.packageName}.OPEN_CALL_LOGS"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/chat/calls")
            putExtra("callId", callId)
        }
        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            ("terminal-$callId").hashCode(),
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(applicationContext, channelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        notificationManager.notify(("terminal-$callId").hashCode(), notification)
    }
}
