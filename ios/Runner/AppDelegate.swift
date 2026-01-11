#if canImport(Flutter)
import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins first, then let FlutterAppDelegate finish setup.
    // This matches Flutter's default template ordering and avoids subtle startup crashes
    // around plugin registration / launch option handling.
    GeneratedPluginRegistrant.register(with: self)

    // Dumb Phone Mode restriction engine method-channel.
    if let registrar = registrar(forPlugin: "RestrictionEnginePlugin") {
      RestrictionEnginePlugin.register(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
#else
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Flutter not available for this build configuration/target.
    // Ensure the app still boots for non-Flutter contexts (e.g., unit tests, previews).
    return true
  }
}
#endif