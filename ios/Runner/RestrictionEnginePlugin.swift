import Flutter
import UIKit

// Screen Time frameworks are iOS 16+. We compile-guard to keep older targets building.
#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(DeviceActivity)
import DeviceActivity
#endif

final class RestrictionEnginePlugin: NSObject {
  private let channelName = "win_flutter/restriction_engine"

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(self, channel: channel)
  }
}

extension RestrictionEnginePlugin: FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    RestrictionEnginePlugin().register(with: registrar)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPermissions":
      result(getPermissions())

    case "requestPermissions":
      requestPermissions(result: result)

    case "startSession":
      // Args: endsAtMillis, allowedApps[], friction{}
      // NOTE: iOS Screen Time APIs require ApplicationToken / FamilyActivitySelection.
      // Converting from bundle id strings is not supported directly. This is an interface
      // boundary scaffold; actual allowlist selection should be driven via a native picker.
      result(nil)

    case "endSession":
      endSession()
      result(nil)

    case "startEmergencyException":
      // For now, this is a no-op scaffold. A real implementation could temporarily remove
      // shields then re-apply them.
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getPermissions() -> [String: Any] {
#if canImport(FamilyControls)
    if #available(iOS 16.0, *) {
      let status = AuthorizationCenter.shared.authorizationStatus
      let isAuthorized = (status == .approved)
      return [
        "isSupported": true,
        "isAuthorized": isAuthorized,
        "needsOnboarding": !isAuthorized,
        "platformDetails": "iOS Screen Time authorization: \(String(describing: status))"
      ]
    }
#endif
    return [
      "isSupported": false,
      "isAuthorized": false,
      "needsOnboarding": true,
      "platformDetails": "Requires iOS 16+ and Screen Time frameworks (FamilyControls/ManagedSettings/DeviceActivity)."
    ]
  }

  private func requestPermissions(result: @escaping FlutterResult) {
#if canImport(FamilyControls)
    if #available(iOS 16.0, *) {
      Task {
        do {
          try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
          result(nil)
        } catch {
          let nsError = error as NSError
          var hint = ""

#if targetEnvironment(simulator)
          hint = "Family Controls authorization isn't supported in the iOS Simulator. Run on a physical device."
#endif

          // NSCocoaErrorDomain Code=4099 + XPC invalidation often shows up when the app is missing
          // the required capability/entitlements or the provisioning profile doesn't include them.
          if nsError.domain == NSCocoaErrorDomain && nsError.code == 4099 && hint.isEmpty {
            hint = "This usually means the app is missing the Family Controls capability/entitlements, or your signing profile doesn't include them."
          }

          let message = hint.isEmpty ? "Screen Time authorization failed" : "Screen Time authorization failed. \(hint)"
          result(FlutterError(code: "AUTH_FAILED", message: message, details: "\(nsError)"))
        }
      }
      return
    }
#endif
    result(FlutterError(code: "UNSUPPORTED", message: "Screen Time APIs unavailable", details: nil))
  }

  private func endSession() {
#if canImport(ManagedSettings)
    if #available(iOS 16.0, *) {
      // ManagedSettingsStore is iOS 15+, but this feature set requires iOS 16+ anyway.
      // Keep the reference inside the availability gate so older deployment targets compile.
      ManagedSettingsStore().clearAllSettings()
    }
#endif
  }
}


