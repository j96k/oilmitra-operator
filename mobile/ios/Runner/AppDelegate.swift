import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps SDK for iOS key, read from Info.plist (GoogleMapsApiKey).
    // Set GOOGLE_MAPS_API_KEY as an Xcode build setting / xcconfig on macOS.
    // When it is empty the app falls back to the OpenStreetMap widget.
    if let key = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String,
       !key.isEmpty, key != "$(GOOGLE_MAPS_API_KEY)" {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
