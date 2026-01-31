# iOS Custom Shield with Task Callout — PRD

> **Status:** 🔮 Future / Research Complete  
> **Priority:** Medium  
> **Complexity:** High (requires native iOS extension targets)  
> **Last Updated:** 2026-01-20

---

## Executive Summary

Enhance the iOS Dumb Phone Mode restriction screens to show **one of the user's remaining tasks** with **cheeky, encouraging messaging** when they try to open a blocked app. Instead of a generic "App Blocked" screen, users see a personalized callout that reminds them what they should be doing.

---

## The Experience

When a user tries to open Instagram (or any blocked app) during Dumb Phone mode:

```
┌─────────────────────────────────────┐
│                                     │
│        🔥 Nice try, champ.          │
│                                     │
│   You could be crushing:            │
│                                     │
│   ┌─────────────────────────────┐   │
│   │  ✓ Submit the Q4 report     │   │
│   └─────────────────────────────┘   │
│                                     │
│   Future you will thank present     │
│   you. Get after it! 💪            │
│                                     │
│   ┌─────────────────────────────┐   │
│   │     Open Win The Year       │   │
│   └─────────────────────────────┘   │
│                                     │
│           [ Okay fine ]             │
│                                     │
└─────────────────────────────────────┘
```

### Key UX Elements

1. **Cheeky headline** — Calls them out with humor, not shame
2. **One featured task** — Not a list, just THE thing to do now (Must-Win priority)
3. **Encouraging closer** — Positive framing, not guilt
4. **Clear CTA** — Open the app to actually do the task
5. **Graceful dismiss** — "Okay fine" closes the shield

---

## Problem Statement

Today, when iOS Screen Time shields appear, they show a generic Apple-provided UI with no context about what the user should be doing instead. This is a missed opportunity to:

- Remind users of their actual priorities
- Use humor to defuse the frustration of being blocked
- Create a moment of positive reinforcement

---

## Goals

- **G1 — Personalized callout**: Shield shows one of the user's actual tasks
- **G2 — Cheeky but supportive tone**: Messages call users out with humor, not shame
- **G3 — Rotating freshness**: Messages change throughout the day so it doesn't feel stale
- **G4 — Clear next action**: Easy path back to the app to complete tasks

---

## Non-Goals (v1)

- Showing multiple tasks on the shield (keep it focused)
- Allowing task completion directly from the shield (iOS limitation)
- Custom animations or complex UI (shield API is limited)
- Android implementation (separate effort, easier)

---

## Technical Architecture

### iOS Shield Extension System

iOS requires **separate app extension targets** to customize Screen Time shields:

| Extension Type | Purpose | Can Read App Group | Can Write App Group |
|----------------|---------|-------------------|---------------------|
| `ShieldConfigurationExtension` | Customize shield UI (title, subtitle, buttons, icon) | ✅ Yes | ❌ No |
| `ShieldActionExtension` | Handle button taps on shield | ✅ Yes | ✅ Yes |

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                               │
│  TodayController → ActiveSessionTaskUnlockController             │
│         │                                                        │
│         ▼                                                        │
│  RestrictionEnginePlugin.swift (syncShieldConfig)                │
│         │                                                        │
│         ▼ (writes to App Group)                                  │
│  UserDefaults(suiteName: "group.com-wintheyear-winFlutter-dev")  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (reads from App Group)
┌─────────────────────────────────────────────────────────────────┐
│              ShieldConfigurationExtension                        │
│  - Reads task data + messages from App Group                     │
│  - Returns custom ShieldConfiguration with cheeky content        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ShieldActionExtension                           │
│  - Handles "Open Win The Year" button tap                        │
│  - Opens app via URL scheme: wintheyear://today                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Limitations ⚠️

1. **Shield extensions run in a separate sandboxed process** — no Flutter, no network calls
2. **Cannot directly open the main app** via public API — Apple blocks this
3. **Workaround**: Use URL schemes + local notifications to guide user back
4. **Data sync is one-way**: Flutter → App Group → Extension
5. **Shield UI may cache** — changes aren't instant
6. **Must test on physical device** — shields don't show in Simulator
7. **Debug builds may not show custom shields** — use TestFlight/Release

---

## Cheeky Message Bank

### Headlines (caught you)

```
"Nice try, champ."
"We both know this isn't the move."
"Ah, the old 'just checking' trick."
"Plot twist: you have stuff to do."
"Your tasks miss you."
"This app isn't going anywhere."
"Caught you. 👀"
"Let's not and say we didn't."
"Procrastination detected."
"The algorithm can wait."
```

### Task Intro Lines

```
"You could be crushing:"
"Meanwhile, this is waiting:"
"Here's what actually matters:"
"Your actual priority:"
"The thing you said you'd do:"
"Remember this one?"
```

### Encouragement Closers

```
"Future you will thank present you. 💪"
"10 minutes. That's all it takes to start."
"You've got this. Go prove it."
"Small wins → big wins. Start now."
"The hardest part is starting. So start."
"You're closer than you think."
"Done > perfect. Let's go."
"Your focus is your superpower."
"This is the moment. Make it count."
"Win the hour, win the day."
```

---

## Implementation Checklist

### Prerequisites

- [ ] **Apple Developer Account** with Family Controls capability enabled
- [ ] **Physical iOS device** for testing (Simulator won't show custom shields)
- [ ] **TestFlight build** or Release configuration (Debug may not show shields)

### Phase 1: Xcode Project Setup

- [ ] Create new target: **Shield Configuration Extension** (`WinTheYearShieldConfig`)
  - Bundle ID: `com.wintheyear.winFlutter.dev.ShieldConfig`
  - Add to App Group: `group.com-wintheyear-winFlutter-dev`
  - Add Family Controls capability
  
- [ ] Create new target: **Shield Action Extension** (`WinTheYearShieldAction`)
  - Bundle ID: `com.wintheyear.winFlutter.dev.ShieldAction`
  - Add to same App Group
  - Add Family Controls capability

- [ ] Create shared Swift file for data model (`ios/Shared/ShieldTaskData.swift`)
  - Add to both extension targets AND main Runner target

- [ ] Configure entitlements for both extensions

### Phase 2: Native Implementation

- [ ] Implement `ShieldTaskData.swift` shared data model
- [ ] Implement `ShieldConfigurationExtension.swift` with cheeky UI
- [ ] Implement `ShieldActionExtension.swift` with button handlers
- [ ] Add `syncShieldConfig` method to `RestrictionEnginePlugin.swift`
- [ ] Register URL scheme `wintheyear://` in `Info.plist`
- [ ] Handle URL scheme in `SceneDelegate.swift` to navigate to Today

### Phase 3: Flutter Integration

- [ ] Add `syncShieldConfig` to `RestrictionEngine` abstract class
- [ ] Implement in `MethodChannelRestrictionEngine`
- [ ] Create `ShieldTaskInfo` model class
- [ ] Call sync when Dumb Phone session starts
- [ ] Call sync when any task completion changes
- [ ] Call sync (with null) when session ends
- [ ] Handle `wintheyear://today` deep link in router

### Phase 4: Testing

- [ ] Test shield appears on blocked app (physical device, Release build)
- [ ] Test task title displays correctly
- [ ] Test messages rotate by hour
- [ ] Test "Open Win The Year" button works
- [ ] Test "Okay fine" dismisses shield
- [ ] Test shield updates when task completed in app
- [ ] Test celebratory message when all tasks done

---

## Files to Create

```
ios/
├── Shared/
│   └── ShieldTaskData.swift              # Shared data model (new)
├── WinTheYearShieldConfig/
│   ├── ShieldConfigurationExtension.swift # Shield UI (new)
│   ├── Info.plist                         # Extension config (new)
│   └── WinTheYearShieldConfig.entitlements # (new)
├── WinTheYearShieldAction/
│   ├── ShieldActionExtension.swift        # Button handlers (new)
│   ├── Info.plist                         # Extension config (new)
│   └── WinTheYearShieldAction.entitlements # (new)
└── Runner/
    ├── RestrictionEnginePlugin.swift      # Add syncShieldConfig (modify)
    └── Info.plist                         # Add URL scheme (modify)

lib/
├── platform/
│   └── restriction_engine/
│       ├── restriction_engine.dart        # Add syncShieldConfig (modify)
│       └── restriction_engine_channel.dart # Implement sync (modify)
└── features/
    ├── focus/
    │   └── focus_session_controller.dart  # Call sync on start/end (modify)
    └── today/
        └── today_controller.dart          # Call sync on toggle (modify)
```

---

## Code Snippets for Implementation

### ShieldTaskData.swift (Shared Model)

```swift
import Foundation

struct ShieldTask: Codable {
    let id: String
    let title: String
    let completed: Bool
    let type: String // "mustWin" or "niceToDo"
}

struct ShieldConfig: Codable {
    let sessionId: String
    let ymd: String
    let tasks: [ShieldTask]
    let sessionEndsAtMillis: Int64?
    let headlines: [String]
    let taskIntros: [String]
    let closers: [String]
    
    var incompleteTasks: [ShieldTask] {
        tasks.filter { !$0.completed }
    }
    
    var featuredTask: ShieldTask? {
        // Prioritize Must-Wins, then pick first incomplete
        let mustWins = incompleteTasks.filter { $0.type == "mustWin" }
        if let first = mustWins.first { return first }
        return incompleteTasks.first
    }
    
    // Rotate by hour so messages stay fresh but consistent within the hour
    var currentHeadline: String {
        let index = Calendar.current.component(.hour, from: Date()) % max(headlines.count, 1)
        return headlines.isEmpty ? "Nice try." : headlines[index]
    }
    
    var currentTaskIntro: String {
        let index = (Calendar.current.component(.minute, from: Date()) / 10) % max(taskIntros.count, 1)
        return taskIntros.isEmpty ? "You could be doing:" : taskIntros[index]
    }
    
    var currentCloser: String {
        let index = Calendar.current.component(.hour, from: Date()) % max(closers.count, 1)
        return closers.isEmpty ? "You've got this." : closers[index]
    }
    
    static let storageKey = "ios_shield_config_v1"
    static let appGroupId = "group.com-wintheyear-winFlutter-dev"
    
    static func load() -> ShieldConfig? {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ShieldConfig.self, from: data)
    }
    
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
    
    static func clear() {
        UserDefaults(suiteName: appGroupId)?.removeObject(forKey: storageKey)
    }
}
```

### ShieldConfigurationExtension.swift

```swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return buildCheekyShield()
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return buildCheekyShield()
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return buildCheekyShield()
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return buildCheekyShield()
    }
    
    private func buildCheekyShield() -> ShieldConfiguration {
        let config = ShieldConfig.load()
        
        let subtitle: String
        
        if let config = config, let task = config.featuredTask {
            subtitle = """
            \(config.currentTaskIntro)
            
            ✓ \(task.title)
            
            \(config.currentCloser)
            """
        } else if let config = config, config.incompleteTasks.isEmpty {
            subtitle = """
            You crushed your tasks! 🎉
            
            Session still active though.
            Enjoy the boredom—it's good for you.
            """
        } else {
            subtitle = """
            Focus session active.
            
            Open Win The Year to see what's next.
            """
        }
        
        let headline = config?.currentHeadline ?? "Nice try."
        
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.85),
            icon: UIImage(systemName: "flame.fill"),
            title: ShieldConfiguration.Label(text: headline, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.9)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Open Win The Year", color: .white),
            primaryButtonBackgroundColor: UIColor.systemOrange,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Okay, fine", color: UIColor.white.withAlphaComponent(0.7))
        )
    }
}
```

### Flutter Method Channel Addition

```dart
// In restriction_engine_channel.dart

@override
Future<void> syncShieldConfig({
  required String? sessionId,
  required String? ymd,
  required List<ShieldTaskInfo> tasks,
  required DateTime? sessionEndsAt,
}) async {
  try {
    await _channel.invokeMethod<void>('syncShieldConfig', {
      'sessionId': sessionId,
      'ymd': ymd,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'sessionEndsAtMillis': sessionEndsAt?.millisecondsSinceEpoch,
      'headlines': _defaultHeadlines,
      'taskIntros': _defaultTaskIntros,
      'closers': _defaultClosers,
    });
  } on MissingPluginException {
    // No-op on unsupported platforms
  }
}

class ShieldTaskInfo {
  final String id;
  final String title;
  final bool completed;
  final String type;
  
  const ShieldTaskInfo({
    required this.id,
    required this.title,
    required this.completed,
    required this.type,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    'type': type,
  };
}
```

---

## Acceptance Criteria

- [ ] Shield shows cheeky headline (rotates by hour)
- [ ] Shield shows ONE featured task (Must-Win priority)
- [ ] Shield shows encouraging closer message
- [ ] Messages rotate throughout the day (not every view)
- [ ] When all tasks complete, shows celebratory message
- [ ] Primary button styled as orange CTA
- [ ] Secondary "Okay fine" button dismisses shield
- [ ] Task title truncates gracefully if long
- [ ] Shield syncs when task completed in app
- [ ] Deep link `wintheyear://today` opens app to Today screen

---

## Open Questions

1. **Message customization**: Should users be able to customize the cheeky messages in Settings?
2. **Task selection**: Should we always show the first Must-Win, or rotate through tasks?
3. **Celebratory unlock**: When all tasks done, should we auto-unshield or keep blocking?
4. **Analytics**: Track how often shields are shown and which messages appear?

---

## References

- [Apple ManagedSettings Documentation](https://developer.apple.com/documentation/managedsettings)
- [ShieldConfigurationDataSource](https://developer.apple.com/documentation/managedsettingsui/shieldconfigurationdatasource)
- [Family Controls Framework](https://developer.apple.com/documentation/familycontrols)
- Current implementation: `ios/Runner/RestrictionEnginePlugin.swift`
- Task unlock system: `lib/features/focus/task_unlock/`

---

## Changelog

- **2026-01-20**: Initial PRD created from research session
