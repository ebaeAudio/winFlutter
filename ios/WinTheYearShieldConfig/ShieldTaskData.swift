//
//  ShieldTaskData.swift
//  Shared
//
//  Shared data model used by the main app and Shield extensions
//  to display task information on the app restriction shield.
//

import Foundation

/// Data model for passing task info from the main app to the Shield extensions
/// via the App Group shared container.
struct ShieldTaskData: Codable {
    /// The title of the user's top priority task (if any)
    let topTaskTitle: String?
    
    /// When the current focus session ends (milliseconds since epoch)
    let sessionEndsAtMillis: Int64?
    
    /// Whether a focus session is currently active
    let isSessionActive: Bool
    
    /// Timestamp when this data was last updated
    let updatedAtMillis: Int64
    
    init(
        topTaskTitle: String? = nil,
        sessionEndsAtMillis: Int64? = nil,
        isSessionActive: Bool = false
    ) {
        self.topTaskTitle = topTaskTitle
        self.sessionEndsAtMillis = sessionEndsAtMillis
        self.isSessionActive = isSessionActive
        self.updatedAtMillis = Int64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - App Group Storage

extension ShieldTaskData {
    private static let appGroupId = "group.com-wintheyear-winFlutter-dev"
    private static let storageKey = "shield_task_data"
    
    /// Save shield task data to the shared App Group container
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
    
    /// Load shield task data from the shared App Group container
    static func load() -> ShieldTaskData? {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(ShieldTaskData.self, from: data)
    }
    
    /// Clear shield task data from the shared App Group container
    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.removeObject(forKey: storageKey)
    }
}

// MARK: - Cheeky Messages

extension ShieldTaskData {
    /// Returns a cheeky headline that rotates by hour
    static func cheekyHeadline() -> String {
        let headlines = [
            "Wait, you sure?",
            "Really? Right now?",
            "This can wait.",
            "Stay focused! 🎯",
            "Not so fast...",
            "Your future self says thanks.",
            "One more task first?",
            "Distraction detected!",
            "You got this. Stay strong.",
            "Remember why you started.",
        ]
        let hourIndex = Calendar.current.component(.hour, from: Date()) % headlines.count
        return headlines[hourIndex]
    }
    
    /// Returns an encouraging closer message
    static func closerMessage() -> String {
        let messages = [
            "You're doing great. Keep going!",
            "Small wins add up.",
            "Focus now, scroll later.",
            "Your goals are worth it.",
            "Just a little longer!",
        ]
        let minuteIndex = Calendar.current.component(.minute, from: Date()) % messages.count
        return messages[minuteIndex]
    }
}
