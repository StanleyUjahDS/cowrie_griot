package com.griotcowrie.griot_cowrie

import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.griotcowrie.griot_cowrie.R
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class GriotNativeAdFactory(private val layoutInflater: LayoutInflater) : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.griot_native_ad, null) as NativeAdView

        // Default fallbacks (Dark theme colors)
        var primaryColor = 0xFFD4A84F.toInt()
        var onPrimaryColor = 0xFF000000.toInt()
        var surfaceColor = 0xFF0D231D.toInt()
        var onSurfaceColor = 0xFFF5F7FA.toInt()
        var onSurfaceVariantColor = 0xFFB6BEC9.toInt()

        // Extract colors from customOptions with robust parsing
        customOptions?.let { options ->
            fun parseColor(key: String): Int? {
                val value = options[key]
                return when (value) {
                    is Number -> value.toInt()
                    is Long -> value.toInt()
                    is Int -> value
                    else -> null
                }
            }

            parseColor("primary")?.let { primaryColor = it }
            parseColor("onPrimary")?.let { onPrimaryColor = it }
            parseColor("surface")?.let { surfaceColor = it }
            parseColor("onSurface")?.let { onSurfaceColor = it }
            parseColor("onSurfaceVariant")?.let { onSurfaceVariantColor = it }
        }

        // Set background color to match Flutter container
        adView.setBackgroundColor(surfaceColor)

        // Headline
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        (adView.headlineView as? TextView)?.let {
            it.text = nativeAd.headline
            it.setTextColor(onSurfaceColor)
        }

        // Body
        adView.bodyView = adView.findViewById(R.id.ad_body)
        (adView.bodyView as? TextView)?.let {
            if (nativeAd.body == null) {
                it.visibility = View.GONE
            } else {
                it.visibility = View.VISIBLE
                it.text = nativeAd.body
                it.setTextColor(onSurfaceVariantColor)
            }
        }

        // Call to action
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        (adView.callToActionView as? Button)?.let {
            if (nativeAd.callToAction == null) {
                it.visibility = View.INVISIBLE
            } else {
                it.visibility = View.VISIBLE
                it.text = nativeAd.callToAction
                
                // Programmatically create rounded background for CTA
                val shape = GradientDrawable()
                shape.cornerRadius = 24f // pill shape
                shape.setColor(primaryColor)
                it.background = shape
                it.setTextColor(onPrimaryColor)
            }
        }

        // Attribution Badge ("Ad") - Modernized to match iOS
        val attribution = adView.findViewById<TextView>(R.id.ad_attribution)
        attribution?.let {
            val shape = GradientDrawable()
            shape.cornerRadius = 8f
            shape.setColor(primaryColor)
            it.background = shape
            it.setTextColor(onPrimaryColor)
        }

        // Icon
        adView.iconView = adView.findViewById(R.id.ad_app_icon)
        if (nativeAd.icon == null) {
            adView.iconView?.visibility = View.GONE
        } else {
            (adView.iconView as ImageView).setImageDrawable(nativeAd.icon?.drawable)
            adView.iconView?.visibility = View.VISIBLE
            // Clip icon to rounded corners
            adView.iconView?.clipToOutline = true
            adView.iconView?.background = GradientDrawable().apply {
                cornerRadius = 20f
            }
        }

        // Media
        adView.mediaView = adView.findViewById(R.id.ad_media)

        // Advertiser
        adView.advertiserView = adView.findViewById(R.id.ad_advertiser)
        (adView.advertiserView as? TextView)?.let {
            if (nativeAd.advertiser == null) {
                it.visibility = View.GONE
            } else {
                it.text = nativeAd.advertiser
                it.setTextColor(onSurfaceVariantColor)
                it.visibility = View.VISIBLE
            }
        }

        // Assign the ad object to the NativeAdView
        adView.setNativeAd(nativeAd)

        return adView
    }
}
