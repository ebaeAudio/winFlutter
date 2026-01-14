import UIKit
import Flutter

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // When using UIScene + a storyboard-defined FlutterViewController, register plugins
    // here (after the root VC exists) to avoid nil/invalid messenger crashes during
    // AppDelegate didFinishLaunching.
    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      return
    }

    GeneratedPluginRegistrant.register(with: flutterViewController)

    // Dumb Phone Mode restriction engine method-channel.
    if let registrar = flutterViewController.registrar(forPlugin: "RestrictionEnginePlugin") {
      RestrictionEnginePlugin.register(with: registrar)
    }
  }

  // Forward deep links to Flutter plugins when using a SceneDelegate.
  // (Many plugins register as UIApplicationDelegates and won't receive
  // scene(_:openURLContexts:) automatically.)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    _ = UIApplication.shared.delegate?.application?(
      UIApplication.shared,
      open: url,
      options: [:]
    )
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    _ = UIApplication.shared.delegate?.application?(
      UIApplication.shared,
      continue: userActivity,
      restorationHandler: { _ in }
    )
  }
}

