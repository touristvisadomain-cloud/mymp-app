import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The Google Maps key the build put into Info.plist (GMSApiKey, from the
  /// MAPS_API_KEY build setting in ios/Flutter/MapsKey.xcconfig); nil when
  /// there is none, and the app then draws its own maps (lib/maps/google.dart).
  static let mapsKey: String? = {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
    else { return nil }
    let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return key.isEmpty || key.hasPrefix("$(") ? nil : key
  }()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = AppDelegate.mapsKey {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Whether this build carries a Google Maps key.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MyMpMapsKey") {
      let channel = FlutterMethodChannel(
        name: "bd.mymp.app/maps", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "hasKey" {
          result(AppDelegate.mapsKey != nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
