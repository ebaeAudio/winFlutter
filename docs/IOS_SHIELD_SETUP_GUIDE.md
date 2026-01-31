# iOS Custom Shield Setup Guide

This guide explains how to complete the Xcode setup for the iOS Custom Shield with Task Callout feature.

## Overview

The implementation consists of:
1. **ShieldTaskData.swift** - Shared data model (already created in `ios/Shared/`)
2. **WinTheYearShieldConfig** - Shield Configuration Extension (already created)
3. **WinTheYearShieldAction** - Shield Action Extension (already created)
4. **Flutter integration** - Method channel and sync controller (already implemented)

## Xcode Setup Required

The Swift files and plists are created, but you need to add the extension targets in Xcode:

### Step 1: Open the Xcode Project

```bash
open ios/Runner.xcworkspace
```

### Step 2: Add Shield Configuration Extension Target

1. In Xcode, go to **File → New → Target**
2. Select **Shield Configuration Extension** under iOS
3. Name it: `WinTheYearShieldConfig`
4. Bundle Identifier: `com.wintheyear.winFlutter.dev.ShieldConfig`
5. Click **Finish** (don't activate the scheme when prompted)

After creation:
- Delete the auto-generated Swift file (we have our own)
- Add `ios/WinTheYearShieldConfig/ShieldConfigurationExtension.swift` to the target
- Add `ios/Shared/ShieldTaskData.swift` to the target
- Replace the auto-generated `Info.plist` with `ios/WinTheYearShieldConfig/Info.plist`
- Add the entitlements file `ios/WinTheYearShieldConfig/WinTheYearShieldConfig.entitlements`

### Step 3: Add Shield Action Extension Target

1. In Xcode, go to **File → New → Target**
2. Select **Shield Action Extension** under iOS
3. Name it: `WinTheYearShieldAction`
4. Bundle Identifier: `com.wintheyear.winFlutter.dev.ShieldAction`
5. Click **Finish** (don't activate the scheme when prompted)

After creation:
- Delete the auto-generated Swift file (we have our own)
- Add `ios/WinTheYearShieldAction/ShieldActionExtension.swift` to the target
- Add `ios/Shared/ShieldTaskData.swift` to the target
- Replace the auto-generated `Info.plist` with `ios/WinTheYearShieldAction/Info.plist`
- Add the entitlements file `ios/WinTheYearShieldAction/WinTheYearShieldAction.entitlements`

### Step 4: Add ShieldTaskData.swift to Runner Target

1. Select `ios/Shared/ShieldTaskData.swift` in the project navigator
2. In the File Inspector (right panel), under **Target Membership**, check:
   - Runner
   - WinTheYearShieldConfig
   - WinTheYearShieldAction

### Step 5: Configure Signing & Capabilities

For each target (Runner, WinTheYearShieldConfig, WinTheYearShieldAction):

1. Select the target in project settings
2. Go to **Signing & Capabilities**
3. Ensure **Family Controls** capability is added
4. Ensure **App Groups** capability is added with:
   - `group.com-wintheyear-winFlutter-dev`
5. Select your development team

### Step 6: Verify Build Settings

For both extension targets:
- Set **iOS Deployment Target** to 16.0 or higher
- Ensure **PRODUCT_BUNDLE_IDENTIFIER** matches the expected values

## Testing

### Prerequisites
- Physical iOS device (shields don't work in Simulator)
- TestFlight or Release build (Debug builds may not show custom shields)
- Family Controls authorization granted

### Test Steps

1. Build and run on a physical device
2. Grant Screen Time permissions when prompted
3. Configure blocked apps via the app picker
4. Start a Dumb Phone session
5. Try to open a blocked app
6. Verify the custom shield shows:
   - Cheeky headline (rotates by hour)
   - Your top priority task
   - Encouraging closer message
   - "Open Win The Year" button (orange)
   - "Okay, fine" dismiss button

### Debugging

If the custom shield doesn't appear:
1. Ensure you're on a physical device
2. Ensure the build is Release or TestFlight
3. Check that both extension targets are included in the build
4. Verify entitlements are correctly configured
5. Check Console.app for extension logs

## Files Created

```
ios/
├── Shared/
│   └── ShieldTaskData.swift              # Shared data model
├── WinTheYearShieldConfig/
│   ├── ShieldConfigurationExtension.swift # Shield UI
│   ├── Info.plist                         # Extension config
│   └── WinTheYearShieldConfig.entitlements
├── WinTheYearShieldAction/
│   ├── ShieldActionExtension.swift        # Button handlers
│   ├── Info.plist                         # Extension config
│   └── WinTheYearShieldAction.entitlements
└── Runner/
    ├── RestrictionEnginePlugin.swift      # Added syncShieldConfig
    ├── SceneDelegate.swift                # Added deep link handling
    └── Info.plist                         # Added wintheyear:// URL scheme

lib/
├── platform/
│   ├── restriction_engine/
│   │   ├── restriction_engine.dart        # Added syncShieldConfig interface
│   │   ├── restriction_engine_channel.dart # Implemented sync
│   │   └── shield_task_info.dart          # New: Shield task model
│   └── deep_link/
│       └── deep_link_handler.dart         # New: Deep link handler
├── features/
│   └── focus/
│       └── shield_sync_controller.dart    # New: Auto-sync controller
└── app/
    ├── app.dart                           # Added deep link listener
    └── bootstrap.dart                     # Added initialization
```

## How It Works

1. When a Dumb Phone session starts, the `shieldSyncControllerProvider` automatically syncs task data to the App Group
2. The sync includes today's tasks, session info, and cheeky messages
3. When a blocked app is opened, iOS loads the `ShieldConfigurationExtension`
4. The extension reads task data from the App Group and builds the custom UI
5. Messages rotate by hour to stay fresh
6. When tasks are completed, the sync updates automatically
7. When the session ends, the shield config is cleared
