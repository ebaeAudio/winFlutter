import Flutter
import UIKit

private let iosPushAppGroupId = "group.com-wintheyear-winFlutter-dev"

/// Minimal APNs bridge for Flutter.
///
/// Notes:
/// - Silent pushes are "best effort" on iOS. They will not reliably arrive if the
///   user force-quits the app.
/// - This plugin stores the APNs device token and the last received remote focus
///   command id in the App Group so Dart can pick it up on next launch.
final class PushNotificationsPlugin: NSObject, FlutterPlugin {
  private static let channelName = "win_flutter/push_notifications"
  private static let tokenKey = "apns_device_token"
  private static let pendingCommandIdKey = "pending_remote_focus_command_id"
  private static let pendingCommandTimestampKey = "pending_remote_focus_command_timestamp"

  private static var channel: FlutterMethodChannel?

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: iosPushAppGroupId)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = PushNotificationsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    PushNotificationsPlugin.channel = channel
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "register":
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
      result(nil)

    case "getToken":
      result(PushNotificationsPlugin.defaults?.string(forKey: Self.tokenKey))

    case "getPendingRemoteFocusCommandId":
      result(PushNotificationsPlugin.defaults?.string(forKey: Self.pendingCommandIdKey))

    case "clearPendingRemoteFocusCommandId":
      PushNotificationsPlugin.defaults?.removeObject(forKey: Self.pendingCommandIdKey)
      PushNotificationsPlugin.defaults?.removeObject(forKey: Self.pendingCommandTimestampKey)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func setDeviceToken(_ token: String) {
    defaults?.set(token, forKey: tokenKey)
    channel?.invokeMethod("onToken", arguments: ["token": token])
  }

  static func setPendingRemoteFocusCommandId(_ id: String) {
    defaults?.set(id, forKey: pendingCommandIdKey)
    defaults?.set(Date().timeIntervalSince1970, forKey: pendingCommandTimestampKey)
    channel?.invokeMethod("onRemoteFocusCommand", arguments: ["commandId": id])
  }

  /// Entry point from AppDelegate when a remote notification arrives.
  static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
    // Expected payload (sent by Edge Function):
    // {
    //   "aps": { "content-available": 1 },
    //   "remote_focus_command_id": "<uuid>"
    // }
    if let id = userInfo["remote_focus_command_id"] as? String, !id.isEmpty {
      setPendingRemoteFocusCommandId(id)
    }
  }
}

