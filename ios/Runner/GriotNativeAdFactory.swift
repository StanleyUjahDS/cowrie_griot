import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads

class GriotNativeAdFactory: NSObject, FLTNativeAdFactory {
    private func uiColorFromArgb(_ argb: Int64) -> UIColor {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]? = nil) -> NativeAdView? {
        let adView = NativeAdView()

        // Get dynamic colors from Flutter theme
        var primaryColor = UIColor.systemBlue
        var onPrimaryColor = UIColor.white
        var onSurfaceColor = UIColor.label
        var onSurfaceVariantColor = UIColor.secondaryLabel

        if let options = customOptions {
            if let primaryNum = options["primary"] as? NSNumber {
                primaryColor = uiColorFromArgb(primaryNum.int64Value)
            }
            if let onPrimaryNum = options["onPrimary"] as? NSNumber {
                onPrimaryColor = uiColorFromArgb(onPrimaryNum.int64Value)
            }
            if let onSurfaceNum = options["onSurface"] as? NSNumber {
                onSurfaceColor = uiColorFromArgb(onSurfaceNum.int64Value)
            }
            if let onSurfaceVariantNum = options["onSurfaceVariant"] as? NSNumber {
                onSurfaceVariantColor = uiColorFromArgb(onSurfaceVariantNum.int64Value)
            }
        }

        // Define common padding
        let padding: CGFloat = 12

        // Ad Label (Mandatory "Ad" indicator)
        let adLabel = UILabel()
        adLabel.text = "Ad"
        adLabel.font = .systemFont(ofSize: 10, weight: .bold)
        adLabel.textColor = onPrimaryColor
        adLabel.backgroundColor = primaryColor
        adLabel.textAlignment = .center
        adLabel.layer.cornerRadius = 3
        adLabel.clipsToBounds = true
        adLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(adLabel)

        // Icon View
        let iconView = UIImageView()
        iconView.layer.cornerRadius = 8
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill
        iconView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(iconView)
        adView.iconView = iconView

        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headlineLabel.textColor = onSurfaceColor
        headlineLabel.numberOfLines = 1
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel

        // Advertiser
        let advertiserLabel = UILabel()
        advertiserLabel.font = .systemFont(ofSize: 12, weight: .medium)
        advertiserLabel.textColor = onSurfaceVariantColor
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(advertiserLabel)
        adView.advertiserView = advertiserLabel

        // Media View (Flexible)
        let mediaView = MediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(mediaView)
        adView.mediaView = mediaView

        // Body
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = onSurfaceVariantColor
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel

        // Call to Action
        let callToAction = UIButton(type: .system)
        callToAction.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        callToAction.setTitleColor(onPrimaryColor, for: .normal)
        callToAction.backgroundColor = primaryColor
        callToAction.layer.cornerRadius = 12
        callToAction.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(callToAction)
        adView.callToActionView = callToAction

        // Constraints
        NSLayoutConstraint.activate([
            // Headline & Icon Row
            iconView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 4),
            iconView.leftAnchor.constraint(equalTo: adView.leftAnchor, constant: 0),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),

            headlineLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 4),
            headlineLabel.leftAnchor.constraint(equalTo: iconView.rightAnchor, constant: 10),
            headlineLabel.rightAnchor.constraint(equalTo: adView.rightAnchor, constant: 0),

            advertiserLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 2),
            advertiserLabel.leftAnchor.constraint(equalTo: iconView.rightAnchor, constant: 10),
            advertiserLabel.rightAnchor.constraint(equalTo: adView.rightAnchor, constant: 0),

            // Ad Label (Top right relative to headline area for compactness)
            adLabel.centerYAnchor.constraint(equalTo: advertiserLabel.centerYAnchor),
            adLabel.leftAnchor.constraint(equalTo: advertiserLabel.rightAnchor, constant: 6),
            adLabel.widthAnchor.constraint(equalToConstant: 24),
            adLabel.heightAnchor.constraint(equalToConstant: 15),

            // Media View (Flexible space)
            mediaView.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            mediaView.leftAnchor.constraint(equalTo: adView.leftAnchor),
            mediaView.rightAnchor.constraint(equalTo: adView.rightAnchor),

            // Body
            bodyLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 10),
            bodyLabel.leftAnchor.constraint(equalTo: adView.leftAnchor),
            bodyLabel.rightAnchor.constraint(equalTo: adView.rightAnchor),

            // Call To Action (Pinned to bottom)
            callToAction.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
            callToAction.leftAnchor.constraint(equalTo: adView.leftAnchor),
            callToAction.rightAnchor.constraint(equalTo: adView.rightAnchor),
            callToAction.heightAnchor.constraint(equalToConstant: 44),
            callToAction.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: 0)
        ])

        // Priority for MediaView to expand
        mediaView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        mediaView.setContentHuggingPriority(.defaultLow, for: .vertical)

        // Populate data
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        adView.bodyView?.isHidden = nativeAd.body == nil

        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        adView.iconView?.isHidden = nativeAd.icon == nil

        (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        adView.advertiserView?.isHidden = nativeAd.advertiser == nil

        // Essential: Disable user interaction on the CTA button so the NativeAdView handles clicks
        adView.callToActionView?.isUserInteractionEnabled = false

        // Set the native ad object
        adView.nativeAd = nativeAd

        return adView
    }
}
