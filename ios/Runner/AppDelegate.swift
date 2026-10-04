import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads
import UserNotifications
import CallKit
import AVFAudio
import PushKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
  private let shareDefaults = UserDefaults(suiteName: "group.com.griotcowrie.griot_cowrie")
  private var shareEventSink: FlutterEventSink?
  private var voipRegistry: PKPushRegistry?
  private var voipPushToken: String?
  private var voipChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    guard type == .voIP else { return }
    let token = credentials.token.map { String(format: "%02x", $0) }.joined()
    voipPushToken = token
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
    voipChannel?.invokeMethod("voipTokenUpdated", arguments: token)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    voipPushToken = nil
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
    voipChannel?.invokeMethod("voipTokenUpdated", arguments: "")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else { completion(); return }
    let body = payload.dictionaryPayload
    let id = body["id"] as? String ?? UUID().uuidString
    let caller = body["nameCaller"] as? String ?? "Griot contact"
    let handle = body["handle"] as? String ?? caller
    let isVideo = body["isVideo"] as? Bool ?? false
    let callData = flutter_callkit_incoming.Data(
      id: id,
      nameCaller: caller,
      handle: handle,
      type: isVideo ? 1 : 0
    )
    let extra = body.reduce(into: [String: Any]()) { result, item in
      result[String(describing: item.key)] = item.value
    }
    callData.extra = extra as NSDictionary
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
      callData,
      fromPushKit: true,
      completion: completion
    )
  }

  func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
    action.fulfill()
  }

  func onDecline(_ call: Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onEnd(_ call: Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onTimeOut(_ call: Call) {}
  func didActivateAudioSession(_ audioSession: AVAudioSession) {}
  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {}
  func providerDidReset() {}

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let voipChannel = FlutterMethodChannel(name: "griot/native_calls", binaryMessenger: messenger)
    self.voipChannel = voipChannel
    voipChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getVoipToken" else { result(FlutterMethodNotImplemented); return }
      result([
        "token": self?.voipPushToken ?? "",
        "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? ""
      ])
    }
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
