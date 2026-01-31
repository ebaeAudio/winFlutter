import ManagedSettings
import ManagedSettingsUI

private let appGroupId = "group.com-wintheyear-winFlutter-dev"

/// Shield Action Extension that handles button taps on the shield.
///
/// - Primary button: Opens the Win The Year app via URL scheme
/// - Secondary button: Dismisses the shield (user said "Okay, fine")
@available(iOS 16.0, *)
class ShieldActionExtension: ShieldActionDelegate {
    
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }
    
    private func handleAction(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Attempt to open the main app via URL scheme.
            // Note: Due to iOS limitations, this may not work directly from a shield action.
            // The app relies on the user manually opening Win The Year after seeing this shield.
            // We can set a flag to indicate the user wanted to open the app.
            setOpenAppRequested()
            
            // Return .close to dismiss the shield
            completionHandler(.close)
            
        case .secondaryButtonPressed:
            // "Okay, fine" - just dismiss the shield
            completionHandler(.close)
            
        @unknown default:
            completionHandler(.close)
        }
    }
    
    /// Store a flag in App Group that the primary button was pressed.
    /// The main app can check this on launch and potentially show a welcome-back message.
    private func setOpenAppRequested() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: "shield_open_app_requested_at")
    }
}
