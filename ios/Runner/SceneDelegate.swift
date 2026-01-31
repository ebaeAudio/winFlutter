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

    // Push notifications (APNs) method-channel.
    if let registrar = flutterViewController.registrar(forPlugin: "PushNotificationsPlugin") {
      PushNotificationsPlugin.register(with: registrar)
    }
  }

  // Forward deep links to Flutter plugins when using a SceneDelegate.
  // (Many plugins register as UIApplicationDelegates and won't receive
  // scene(_:openURLContexts:) automatically.)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    
    // Handle wintheyear:// deep links for shield navigation
    if handleWinTheYearDeepLink(url) {
      return
    }
    
    _ = UIApplication.shared.delegate?.application?(
      UIApplication.shared,
      open: url,
      options: [:]
    )
  }
  
  /// Handle wintheyear:// deep links (e.g., from shield "Open Win The Year" button)
  ///
  /// Supported paths:
  /// - wintheyear://today → Navigate to Today screen
  /// - wintheyear://focus → Navigate to Focus screen
  private func handleWinTheYearDeepLink(_ url: URL) -> Bool {
    guard url.scheme == "wintheyear" else { return false }
    
    // Store the intended route in App Group so Flutter can pick it up
    let route: String
    switch url.host?.lowercased() ?? url.path.lowercased() {
    case "today", "/today", "":
      route = "/today"
    case "focus", "/focus":
      route = "/focus"
    default:
      route = "/today"
    }
    
    // Write the pending route to App Group for Flutter to consume
    let appGroupId = "group.com-wintheyear-winFlutter-dev"
    if let defaults = UserDefaults(suiteName: appGroupId) {
      defaults.set(route, forKey: "pending_deep_link_route")
      defaults.set(Date().timeIntervalSince1970, forKey: "pending_deep_link_timestamp")
    }
    
    // Send a notification to the Flutter engine via method channel
    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "win_flutter/deep_link",
        binaryMessenger: flutterViewController.binaryMessenger
      )
      channel.invokeMethod("onDeepLink", arguments: ["route": route])
    }
    
    return true
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    _ = UIApplication.shared.delegate?.application?(
      UIApplication.shared,
      continue: userActivity,
      restorationHandler: { _ in }
    )
  }
}

