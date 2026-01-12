#if canImport(Flutter)
import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // With a SceneDelegate + storyboard-driven FlutterViewController, the Flutter
    // engine/binary messenger is not guaranteed to be ready during AppDelegate
    // didFinishLaunching. Registering plugins here can crash (EXC_BAD_ACCESS)
    // when a plugin creates channels using a nil/invalid messenger.
    //
    // Plugin registration is performed in SceneDelegate once the window's root
    // FlutterViewController exists.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @available(iOS 13.0, *)
  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    return UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
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

