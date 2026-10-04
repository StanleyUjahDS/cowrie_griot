package com.griotcowrie.griot_cowrie

import android.content.Intent
import android.net.Uri
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private var shareEventSink: EventChannel.EventSink? = null
    private var pendingShare: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createPushNotificationChannel()

        pendingShare = extractShare(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "griot/share_receiver")
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialShare") {
                    result.success(pendingShare)
                    pendingShare = null
                } else {
                    result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "griot/share_receiver/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    shareEventSink = null
                }
            })

        Log.d("MainActivity", "Configuring Flutter Engine and registering NativeAdFactory")

        try {
            // Register the NativeAdFactory
            val factory = GriotNativeAdFactory(layoutInflater)
            GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "griot_native_ad", factory)
            Log.d("MainActivity", "NativeAdFactory registered successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to register NativeAdFactory", e)
        }
    }

    private fun createPushNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "high_importance_channel",
            "Griot notifications",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Messages, connection requests, and call alerts"
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        val ringtone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val callChannel = NotificationChannel(
            "incoming_calls",
            "Incoming calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Incoming Griot voice and video calls"
            enableVibration(true)
            setSound(
                ringtone,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(callChannel)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractShare(intent)?.let { shareEventSink?.success(it) }
    }

    private fun extractShare(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return null

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val mimeType = intent.type
        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
        val filePath = uri?.let { copySharedFile(it) }

        if (text.isNullOrBlank() && filePath == null) return null
        return mapOf(
            "text" to text,
            "subject" to subject,
            "mimeType" to mimeType,
            "filePath" to filePath,
        )
    }

    private fun copySharedFile(uri: Uri): String? {
        return try {
            val directory = File(cacheDir, "shared_content").apply { mkdirs() }
            val extension = contentResolver.getType(uri)
                ?.substringAfter('/', "bin")
                ?.replace("+", "_")
                ?: "bin"
            val destination = File(directory, "shared_${System.currentTimeMillis()}.$extension")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destination).use { output -> input.copyTo(output) }
            }
            destination.absolutePath.takeIf { destination.exists() }
        } catch (error: Exception) {
            Log.e("MainActivity", "Unable to copy shared content", error)
            null
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        Log.d("MainActivity", "Cleaning up Flutter Engine and unregistering NativeAdFactory")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "griot_native_ad")
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
