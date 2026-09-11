import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let shareDefaults = UserDefaults(suiteName: "group.com.griotcowrie.griot_cowrie")
  private var shareEventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let methodChannel = FlutterMethodChannel(name: "griot/share_receiver", binaryMessenger: messenger)
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getInitialShare" else { result(FlutterMethodNotImplemented); return }
      result(self?.consumePendingShare())
    }
    let eventChannel = FlutterEventChannel(name: "griot/share_receiver/events", binaryMessenger: messenger)
    eventChannel.setStreamHandler(self)

    // Register the NativeAdFactory with the implicit engine's plugin registry
    let factory = GriotNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(engineBridge.pluginRegistry, factoryId: "griot_native_ad", nativeAdFactory: factory)
  }

  override func application(_ app: UIApplication, open url: URL,
                             options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if url.scheme == "griot", url.host == "share", let shareEventSink {
      if let payload = consumePendingShare() { shareEventSink(payload) }
      return true
    }
    return super.application(app, open: url, options: options)
  }

  private func consumePendingShare() -> [String: Any]? {
    guard let payload = shareDefaults?.dictionary(forKey: "pending_shared_content") else { return nil }
    shareDefaults?.removeObject(forKey: "pending_shared_content")
    return payload
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    shareEventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    shareEventSink = nil
    return nil
  }
}
