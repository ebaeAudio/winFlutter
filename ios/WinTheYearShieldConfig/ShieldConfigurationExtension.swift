//
//  ShieldConfigurationExtension.swift
//  WinTheYearShieldConfig
//
//  Custom shield that displays the user's top task and encouraging messages.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Custom Shield Configuration that shows task info and cheeky messages
/// when the user tries to open a blocked app during a focus session.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    // MARK: - Shield Configuration
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeShieldConfiguration()
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeShieldConfiguration()
    }
    
    // MARK: - Private
    
    private func makeShieldConfiguration() -> ShieldConfiguration {
        // Try to load the shared config from App Group
        let config = ShieldConfig.load()
        
        let headline = config?.currentHeadline ?? "Nice try."
        let taskIntro = config?.currentTaskIntro ?? "While you're here…"
        let closer = config?.currentCloser ?? "You've got this."
        let featuredTaskTitle = config?.featuredTask?.title
        
        // Build subtitle: if we have a featured task, show it with intro; otherwise just closer
        let subtitle: String
        if let task = featuredTaskTitle {
            subtitle = "\(taskIntro)\n\(task)"
        } else {
            subtitle = closer
        }
        
        // Create the labels
        let titleLabel = ShieldConfiguration.Label(
            text: headline,
            color: .white
        )
        
        let subtitleLabel = ShieldConfiguration.Label(
            text: subtitle,
            color: UIColor.white.withAlphaComponent(0.8)
        )
        
        // Orange brand color for primary button
        let brandOrange = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.95),
            icon: nil,
            title: titleLabel,
            subtitle: subtitleLabel,
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Win The Year",
                color: .white
            ),
            primaryButtonBackgroundColor: brandOrange,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Okay, fine",
                color: UIColor.white.withAlphaComponent(0.7)
            )
        )
    }
}
