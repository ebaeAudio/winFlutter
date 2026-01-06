import Flutter
import UIKit

// Screen Time frameworks are iOS 16+. We compile-guard to keep older targets building.
#if canImport(FamilyControls)
import FamilyControls
import SwiftUI
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(DeviceActivity)
import DeviceActivity
#endif

private let iosFocusAppGroupId = "group.com-wintheyear-winFlutter-dev"

final class RestrictionEnginePlugin: NSObject {
  private let channelName = "win_flutter/restriction_engine"

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(self, channel: channel)
  }
}

#if canImport(FamilyControls)
@available(iOS 16.0, *)
private final class IOSFocusState {
  static let shared = IOSFocusState()

  private init() {}

  // Persist selection so the picker choice survives app restarts.
  private var defaults: UserDefaults? {
    // NOTE: Must match Runner.entitlements app group.
    UserDefaults(suiteName: iosFocusAppGroupId)
  }

  private let selectionKey = "ios_focus_blocked_selection"
  private let endsAtMillisKey = "ios_focus_ends_at_millis"

  private var endWorkItem: DispatchWorkItem?

  func saveSelection(_ selection: FamilyActivitySelection) {
    // FamilyActivitySelection conforms to Codable.
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(selection) {
      defaults?.set(data, forKey: selectionKey)
    }
  }

  func loadSelection() -> FamilyActivitySelection? {
    guard let data = defaults?.data(forKey: selectionKey) else { return nil }
    let decoder = JSONDecoder()
    return try? decoder.decode(FamilyActivitySelection.self, from: data)
  }

  func saveEndsAtMillis(_ millis: Int64?) {
    if let millis {
      defaults?.set(millis, forKey: endsAtMillisKey)
    } else {
      defaults?.removeObject(forKey: endsAtMillisKey)
    }
  }

  func cancelScheduledEnd() {
    endWorkItem?.cancel()
    endWorkItem = nil
  }

  func scheduleEnd(atMillis: Int64, onEnd: @escaping () -> Void) {
    cancelScheduledEnd()
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    let delayMillis = max(0, atMillis - now)
    let item = DispatchWorkItem(block: onEnd)
    endWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delayMillis)), execute: item)
  }
}

@available(iOS 16.0, *)
private struct IOSFocusAppPickerView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var selection: FamilyActivitySelection
  private let onDone: (FamilyActivitySelection) -> Void

  init(initial: FamilyActivitySelection, onDone: @escaping (FamilyActivitySelection) -> Void) {
    _selection = State(initialValue: initial)
    self.onDone = onDone
  }

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle("Choose apps to block")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
              onDone(selection)
              dismiss()
            }
          }
        }
    }
  }
}
#endif

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

    case "configureApps":
#if canImport(FamilyControls)
      if #available(iOS 16.0, *) {
        showAppPicker(result: result)
        return
      }
#endif
      result(FlutterError(code: "UNSUPPORTED", message: "Screen Time APIs unavailable", details: nil))

    case "startSession":
#if canImport(FamilyControls) && canImport(ManagedSettings)
      if #available(iOS 16.0, *) {
        startSession(call: call, result: result)
        return
      }
#endif
      result(FlutterError(code: "UNSUPPORTED", message: "Screen Time APIs unavailable", details: nil))

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
#if canImport(FamilyControls)
    if #available(iOS 16.0, *) {
      IOSFocusState.shared.cancelScheduledEnd()
      IOSFocusState.shared.saveEndsAtMillis(nil)
    }
#endif
  }

#if canImport(FamilyControls)
  @available(iOS 16.0, *)
  private func showAppPicker(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let root = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow })?
        .rootViewController
      else {
        result(FlutterError(code: "NO_UI", message: "Unable to present app picker", details: nil))
        return
      }

      let initial = IOSFocusState.shared.loadSelection() ?? FamilyActivitySelection()
      let view = IOSFocusAppPickerView(initial: initial) { selection in
        IOSFocusState.shared.saveSelection(selection)
      }
      let host = UIHostingController(rootView: view)
      host.modalPresentationStyle = .formSheet
      root.present(host, animated: true) {
        result(nil)
      }
    }
  }
#endif

#if canImport(FamilyControls) && canImport(ManagedSettings)
  @available(iOS 16.0, *)
  private func startSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = (call.arguments as? [String: Any]) ?? [:]
    let endsAtMillis = (args["endsAtMillis"] as? NSNumber)?.int64Value ?? 0

    let selection = IOSFocusState.shared.loadSelection() ?? FamilyActivitySelection()
    let hasApps = !selection.applicationTokens.isEmpty
    let hasCats = !selection.categoryTokens.isEmpty

    if !hasApps && !hasCats {
      result(
        FlutterError(
          code: "NO_SELECTION",
          message: "No blocked apps selected. Call configureApps first.",
          details: nil
        )
      )
      return
    }

    // Apply shields (block the selected apps/categories).
    let store = ManagedSettingsStore()
    store.shield.applications = hasApps ? selection.applicationTokens : nil
    store.shield.applicationCategories = hasCats ? .specific(selection.categoryTokens) : nil

    // Best-effort auto-end while the app process is alive.
    if endsAtMillis > 0 {
      IOSFocusState.shared.saveEndsAtMillis(endsAtMillis)
      IOSFocusState.shared.scheduleEnd(atMillis: endsAtMillis) { [weak store] in
        // Clear settings when timer elapses.
        // (If the app is killed, this won't run; a DeviceActivity monitor is needed for true system-timed ends.)
        store?.clearAllSettings()
        IOSFocusState.shared.saveEndsAtMillis(nil)
      }
    }

    result(nil)
  }
#endif
}


