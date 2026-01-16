import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  private var dockBadgeChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }

    // Set up Dock Badge method channel
    dockBadgeChannel = FlutterMethodChannel(
      name: "com.wintheyear.app/dock_badge",
      binaryMessenger: controller.engine.binaryMessenger
    )

    dockBadgeChannel?.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "setBadgeCount":
        if let args = call.arguments as? [String: Any],
           let count = args["count"] as? Int {
          self?.setBadgeCount(count)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "count is required", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setBadgeCount(_ count: Int) {
    if count <= 0 {
      // Clear the badge
      NSApp.dockTile.badgeLabel = nil
    } else {
      // Set the badge count
      NSApp.dockTile.badgeLabel = "\(count)"
    }
  }
}
