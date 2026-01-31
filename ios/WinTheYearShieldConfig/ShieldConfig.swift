//
//  ShieldConfig.swift
//  WinTheYearShieldConfig
//
//  Lightweight model used by ShieldConfigurationExtension to populate shield UI.
//  If your main app provides a shared configuration, replace the `load()` implementation
//  to read from App Group container or ManagedSettings communication as appropriate.
//

import Foundation

public struct ShieldConfig: Codable, Sendable {
    public struct Task: Codable, Sendable {
        public let title: String
        public init(title: String) { self.title = title }
    }

    // Headline shown at the top of the shield
    public let currentHeadline: String

    // Intro that precedes the featured task in the subtitle body
    public let currentTaskIntro: String

    // Closer that follows the featured task in the subtitle body
    public let currentCloser: String

    // The task to feature prominently
    public let featuredTask: Task?

    // Any remaining tasks (not directly displayed here but used for logic)
    public let incompleteTasks: [Task]

    public init(currentHeadline: String,
                currentTaskIntro: String,
                currentCloser: String,
                featuredTask: Task?,
                incompleteTasks: [Task]) {
        self.currentHeadline = currentHeadline
        self.currentTaskIntro = currentTaskIntro
        self.currentCloser = currentCloser
        self.featuredTask = featuredTask
        self.incompleteTasks = incompleteTasks
    }
}

public extension ShieldConfig {
    /// Attempts to load a shared configuration for the shield.
    /// Replace this stub with real loading from an App Group or other shared storage if available.
    static func load() -> ShieldConfig? {
        // TODO: Integrate with your shared data source. For now, return a sensible default
        // so the extension compiles and presents a coherent UI.
        return ShieldConfig(
            currentHeadline: "Nice try.",
            currentTaskIntro: "While you're here… how about tackling this next?",
            currentCloser: "One step at a time. You've got this.",
            featuredTask: Task(title: "Review today's top priority"),
            incompleteTasks: [Task(title: "Plan tomorrow"), Task(title: "Log a win for today")]
        )
    }
}
