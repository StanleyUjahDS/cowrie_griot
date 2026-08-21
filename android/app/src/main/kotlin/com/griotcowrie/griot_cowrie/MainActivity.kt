package com.griotcowrie.griot_cowrie

import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        Log.d("MainActivity", "Cleaning up Flutter Engine and unregistering NativeAdFactory")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "griot_native_ad")
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
