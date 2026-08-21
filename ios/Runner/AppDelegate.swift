import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Register the NativeAdFactory with the implicit engine's plugin registry
    let factory = GriotNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(engineBridge.pluginRegistry, factoryId: "griot_native_ad", nativeAdFactory: factory)
  }
}
