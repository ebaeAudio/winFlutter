# iOS/Xcode Setup Guide for Brick App Features

Complete step-by-step guide for configuring Xcode, certificates, entitlements, and all Apple-specific settings needed to implement Brick app features on iOS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Apple Developer Account Setup](#apple-developer-account-setup)
3. [Xcode Project Configuration](#xcode-project-configuration)
4. [Capabilities & Entitlements](#capabilities--entitlements)
5. [Certificates & Provisioning Profiles](#certificates--provisioning-profiles)
6. [Info.plist Configuration](#infoplist-configuration)
7. [Build Settings](#build-settings)
8. [Testing Configuration](#testing-configuration)
9. [App Store Submission](#app-store-submission)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software
- **Xcode 14.0+** (recommended: latest version)
- **macOS 12.0+** (for Xcode compatibility)
- **iOS 16.0+** (required for Family Controls API)
- **Flutter SDK** (already installed)

### Required Accounts
- **Apple Developer Account** ($99/year)
  - Individual or Organization account
  - Active membership required

### Required Devices
- **Physical iPhone** (iOS 16.0+)
  - ⚠️ **Critical**: Family Controls API does NOT work in iOS Simulator
  - Must test on real device

---

## Apple Developer Account Setup

### Step 1: Enroll in Apple Developer Program

1. Go to [developer.apple.com](https://developer.apple.com)
2. Click **"Account"** → **"Enroll"**
3. Complete enrollment process ($99/year)
4. Wait for approval (usually instant for individuals, 24-48 hours for organizations)

### Step 2: Access Developer Portal

1. Log in to [developer.apple.com/account](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Verify your account is active

### Step 3: Create App Identifier

1. In Developer Portal, go to **Identifiers** → **App IDs**
2. Click **"+"** to create new App ID
3. Select **"App"** → Continue
4. Fill in:
   - **Description**: "Win Flutter" (or your app name)
   - **Bundle ID**: `com.yourcompany.winflutter` (must match your Xcode project)
5. **Enable Capabilities**:
   - ✅ **Family Controls** (required)
   - ✅ **App Groups** (required for app blocking)
6. Click **Continue** → **Register**

**Important**: Note your Bundle ID - you'll need it everywhere!

---

## Xcode Project Configuration

### Step 1: Open Project in Xcode

```bash
cd /Users/evan.beyrer/workspace/winFlutter
open ios/Runner.xcworkspace
```

**Note**: Use `.xcworkspace`, not `.xcodeproj` (for CocoaPods)

### Step 2: Select Target

1. In Xcode, click **Runner** project in left sidebar
2. Select **Runner** target (under TARGETS)
3. Click **"Signing & Capabilities"** tab

### Step 3: Configure Signing

1. **Team**: Select your Apple Developer team
   - If not listed, click **"Add Account..."** and sign in
2. **Bundle Identifier**: Set to match your App ID
   - Example: `com.yourcompany.winflutter`
3. **Automatically manage signing**: ✅ Check this box
   - Xcode will handle certificates automatically

### Step 4: Set Deployment Target

1. Still in **Signing & Capabilities** tab
2. Scroll to **"Deployment Info"** section
3. Set **iOS Deployment Target** to **16.0** (minimum for Family Controls)
   - Or use **"General"** tab → **"Minimum Deployments"**

---

## Capabilities & Entitlements

### Step 1: Add Family Controls Capability

1. In **Signing & Capabilities** tab
2. Click **"+ Capability"** button (top left)
3. Search for **"Family Controls"**
4. Double-click to add
5. Xcode will automatically:
   - Add entitlement to `Runner.entitlements`
   - Configure App Groups

### Step 2: Add App Groups Capability

1. Click **"+ Capability"** again
2. Search for **"App Groups"**
3. Double-click to add
4. Click **"+**" under App Groups
5. Enter: `group.com.yourcompany.winflutter`
   - Format: `group.` + your bundle ID
6. Click **OK**

### Step 3: Verify Entitlements File

**File**: `ios/Runner/Runner.entitlements`

Should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Family Controls -->
    <key>com.apple.developer.family-controls</key>
    <true/>
    
    <!-- App Groups -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.winflutter</string>
    </array>
</dict>
</plist>
```

**⚠️ Important**: 
- The App Group identifier must match exactly in:
  - Xcode App Groups capability
  - `Runner.entitlements` file
  - Developer Portal App ID configuration

### Step 4: Update Your Entitlements File

Your current `Runner.entitlements` has:
```xml
<key>com.apple.developer.family-controls.user-management</key>
<true/>
```

**Replace it with**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Family Controls - Required for app blocking -->
    <key>com.apple.developer.family-controls</key>
    <true/>
    
    <!-- App Groups - Required for sharing data between app and system -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.winflutter</string>
    </array>
</dict>
</plist>
```

**Note**: Replace `com.yourcompany.winflutter` with your actual bundle ID.

---

## Certificates & Provisioning Profiles

### Automatic Signing (Recommended)

If you checked **"Automatically manage signing"**:

1. Xcode will automatically:
   - Create/update certificates
   - Generate provisioning profiles
   - Handle renewals

2. **Verify it worked**:
   - Look for green checkmark ✅ next to "Signing Certificate"
   - Should show: "Apple Development: your@email.com"
   - Provisioning profile should be auto-generated

### Manual Signing (If Needed)

If automatic signing fails:

#### Step 1: Create Certificate

1. In Developer Portal → **Certificates**
2. Click **"+"** → **"Apple Development"** → Continue
3. Upload CSR (Certificate Signing Request):
   - Open **Keychain Access** app
   - Menu → **Certificate Assistant** → **Request a Certificate**
   - Enter email, name, select **"Save to disk"**
   - Upload the `.certSigningRequest` file
4. Download certificate → Double-click to install

#### Step 2: Create Provisioning Profile

1. Developer Portal → **Profiles**
2. Click **"+"** → **"iOS App Development"** → Continue
3. Select your **App ID** → Continue
4. Select your **Certificate** → Continue
5. Select **Devices** (your iPhone) → Continue
6. Name it: "Win Flutter Development" → Generate
7. Download → Double-click to install

#### Step 3: Configure in Xcode

1. Xcode → **Signing & Capabilities**
2. Uncheck **"Automatically manage signing"**
3. Select **Provisioning Profile** → Choose downloaded profile

---

## Info.plist Configuration

### Step 1: Add Usage Descriptions

**File**: `ios/Runner/Info.plist`

Add these keys (required for App Store):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing keys... -->
    
    <!-- Family Controls Usage Description -->
    <key>NSFamilyControlsUsageDescription</key>
    <string>We need access to Family Controls to help you block distracting apps and stay focused. This allows us to restrict access to apps you choose during focus mode.</string>
    
    <!-- Optional: Location (if using location-based profiles) -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>We use your location to automatically activate focus mode when you arrive at work or home.</string>
    
    <!-- Optional: Notifications -->
    <key>NSUserNotificationsUsageDescription</key>
    <string>We need notification access to filter and manage your notifications during focus mode.</string>
</dict>
</plist>
```

### Step 2: Update Your Info.plist

Your current `Info.plist` is missing usage descriptions. Add them:

**After line 27** (after `CFBundleVersion`), add:

```xml
	<!-- Family Controls Usage Description -->
	<key>NSFamilyControlsUsageDescription</key>
	<string>Win Flutter needs access to Screen Time to help you block distracting apps and stay focused during focus mode.</string>
```

### Step 3: Minimum iOS Version

Ensure minimum iOS version is set:

1. In Xcode → **General** tab
2. **Minimum Deployments** → iOS **16.0**
3. Or in `Info.plist`, ensure `MinimumOSVersion` is `16.0`

---

## Build Settings

### Step 1: Set iOS Deployment Target

1. Xcode → Select **Runner** project
2. Select **Runner** target
3. **Build Settings** tab
4. Search for **"iOS Deployment Target"**
5. Set to **16.0** (or higher)

### Step 2: Swift Language Version

1. **Build Settings** tab
2. Search for **"Swift Language Version"**
3. Set to **Swift 5** (or latest)

### Step 3: Enable Bitcode (if needed)

1. **Build Settings** tab
2. Search for **"Enable Bitcode"**
3. Set to **No** (Bitcode is deprecated)

### Step 4: Code Signing

1. **Build Settings** tab
2. Search for **"Code Signing Identity"**
3. **Debug**: `Apple Development`
4. **Release**: `Apple Distribution`

---

## Testing Configuration

### Step 1: Connect Physical iPhone

1. Connect iPhone via USB
2. Unlock iPhone
3. Trust computer if prompted
4. In Xcode, select your iPhone from device dropdown (top toolbar)

### Step 2: Enable Developer Mode (iOS 16+)

On your iPhone:

1. **Settings** → **Privacy & Security**
2. Scroll to **Developer Mode**
3. Toggle **ON**
4. Restart iPhone when prompted
5. Enter passcode to confirm

### Step 3: Trust Developer Certificate

On your iPhone (first time only):

1. When you run app, you'll see: **"Untrusted Developer"**
2. Go to **Settings** → **General** → **VPN & Device Management**
3. Tap your developer certificate
4. Tap **"Trust [Your Name]"**
5. Confirm

### Step 4: Build and Run

1. In Xcode, select your iPhone as target
2. Click **Play** button (▶️) or press `Cmd+R`
3. Wait for build to complete
4. App should install and launch on iPhone

### Step 5: Test Family Controls Authorization

1. When app launches, it should request Family Controls permission
2. Tap **"Allow"**
3. If you see error, check:
   - Entitlements file is correct
   - App Groups is configured
   - Running on physical device (not simulator)

---

## App Store Submission

### Step 1: Create App Store Listing

1. Developer Portal → **App Store Connect**
2. **My Apps** → **"+"** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: "Win Flutter" (or your name)
   - **Primary Language**: English
   - **Bundle ID**: Select your App ID
   - **SKU**: Unique identifier (e.g., `win-flutter-001`)
4. Click **Create**

### Step 2: Configure App Information

1. **App Information** tab:
   - Category: **Productivity** or **Lifestyle**
   - Privacy Policy URL (required)
   - Support URL

2. **Pricing and Availability**:
   - Set price (Free or Paid)
   - Select countries

### Step 3: Prepare for Submission

1. **App Privacy**:
   - Declare data collection
   - Family Controls usage
   - Screen Time data

2. **App Review Information**:
   - Contact information
   - Demo account (if needed)
   - Notes: "Uses Family Controls API for app blocking feature"

### Step 4: Archive and Upload

1. In Xcode:
   - Select **"Any iOS Device"** as target (not simulator)
   - **Product** → **Archive**
   - Wait for archive to complete

2. **Organizer** window opens:
   - Select your archive
   - Click **"Distribute App"**
   - Choose **"App Store Connect"**
   - Follow wizard to upload

3. **App Store Connect**:
   - Go to your app → **TestFlight** tab
   - Wait for processing (10-30 minutes)
   - Add to **Internal Testing** or **External Testing**

### Step 5: Submit for Review

1. **App Store Connect** → Your app
2. **App Store** tab → **"+"** next to version
3. Fill in:
   - **What's New**: Version notes
   - **Screenshots**: Required (various sizes)
   - **Description**: App description
   - **Keywords**: Search keywords
   - **Support URL**: Your support page
   - **Marketing URL**: (optional)
4. **Build**: Select your uploaded build
5. **App Review Information**:
   - Notes: Explain Family Controls usage
   - Contact info
6. Click **Submit for Review**

### Step 6: App Review Notes

In **App Review Information** → **Notes**, include:

```
This app uses the Family Controls framework to help users block distracting apps during focus mode. 

Key features:
- Uses Screen Time API (FamilyControls) to restrict app access
- Requires user authorization (one-time approval)
- App Groups capability is used for system integration

Testing:
- Requires physical iPhone (iOS 16.0+)
- User must grant Family Controls permission in Settings
- Test on device, not simulator

If you need a demo account or have questions, please contact [your email].
```

---

## Troubleshooting

### Issue: "Family Controls authorization failed"

**Symptoms**:
- Error code: `NSCocoaErrorDomain Code=4099`
- Authorization always returns denied

**Solutions**:

1. **Check Entitlements**:
   ```bash
   # Verify entitlements file
   cat ios/Runner/Runner.entitlements
   ```
   Should contain `com.apple.developer.family-controls`

2. **Check App Groups**:
   - Must be configured in Xcode
   - Must match in entitlements file
   - Must match in Developer Portal

3. **Check Provisioning Profile**:
   - Must include Family Controls capability
   - Regenerate if needed

4. **Physical Device**:
   - ⚠️ **Must test on real iPhone**
   - Simulator will always fail

5. **iOS Version**:
   - Must be iOS 16.0+
   - Check: Settings → General → About → Software Version

### Issue: "Missing required capability"

**Symptoms**:
- Build fails with capability error
- Xcode shows red error

**Solutions**:

1. **Add Capability in Xcode**:
   - Signing & Capabilities → "+ Capability"
   - Add Family Controls
   - Add App Groups

2. **Check Developer Portal**:
   - App ID must have capabilities enabled
   - Regenerate provisioning profile

3. **Clean Build**:
   ```bash
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   ```
   Then in Xcode: **Product** → **Clean Build Folder** (`Cmd+Shift+K`)

### Issue: "Code signing failed"

**Symptoms**:
- Build error about signing
- Certificate issues

**Solutions**:

1. **Check Team**:
   - Xcode → Signing & Capabilities
   - Select correct team

2. **Automatic Signing**:
   - Enable "Automatically manage signing"
   - Let Xcode handle it

3. **Manual Signing**:
   - Download certificate from Developer Portal
   - Install in Keychain
   - Select in Xcode

4. **Provisioning Profile**:
   - Must include your device UDID
   - Add device in Developer Portal if needed

### Issue: "App Groups not working"

**Symptoms**:
- App Group identifier mismatch
- Data not sharing

**Solutions**:

1. **Verify Identifier**:
   - Format: `group.com.yourcompany.appname`
   - Must start with `group.`
   - Must match in all places

2. **Check All Locations**:
   - Xcode App Groups capability
   - `Runner.entitlements` file
   - Developer Portal App ID

3. **Case Sensitive**:
   - Must match exactly (case-sensitive)

### Issue: "Cannot test in Simulator"

**Symptoms**:
- Family Controls doesn't work
- Authorization fails

**Solution**:
- ⚠️ **This is expected behavior**
- Family Controls API **does not work in Simulator**
- **Must use physical iPhone**

### Issue: "Build fails with Swift errors"

**Symptoms**:
- Compilation errors
- Framework not found

**Solutions**:

1. **Check iOS Deployment Target**:
   - Must be 16.0+ for Family Controls

2. **Check Swift Version**:
   - Build Settings → Swift Language Version → Swift 5

3. **Import Statements**:
   ```swift
   #if canImport(FamilyControls)
   import FamilyControls
   #endif
   ```

4. **Clean Build**:
   ```bash
   flutter clean
   cd ios
   pod install
   ```

### Issue: "App Store rejection"

**Symptoms**:
- Rejected for Family Controls usage
- Privacy concerns

**Solutions**:

1. **App Review Notes**:
   - Clearly explain Family Controls usage
   - Provide demo account
   - Explain user benefit

2. **Privacy Policy**:
   - Must mention Screen Time data
   - Explain data usage

3. **User Experience**:
   - Clear permission requests
   - Explain why permission is needed

---

## Verification Checklist

Before submitting, verify:

### Xcode Configuration
- [ ] Bundle ID matches Developer Portal
- [ ] Team is selected
- [ ] Signing is configured (automatic or manual)
- [ ] iOS Deployment Target is 16.0+
- [ ] Family Controls capability added
- [ ] App Groups capability added
- [ ] App Group identifier matches everywhere

### Entitlements
- [ ] `Runner.entitlements` has `com.apple.developer.family-controls`
- [ ] `Runner.entitlements` has App Groups array
- [ ] App Group identifier matches Xcode and Developer Portal

### Info.plist
- [ ] `NSFamilyControlsUsageDescription` is present
- [ ] Usage description is user-friendly
- [ ] Minimum iOS version is 16.0+

### Developer Portal
- [ ] App ID created
- [ ] Family Controls enabled on App ID
- [ ] App Groups enabled on App ID
- [ ] App Group identifier matches

### Testing
- [ ] Tested on physical iPhone (not simulator)
- [ ] Family Controls authorization works
- [ ] App blocking works
- [ ] App Groups work

### App Store Connect
- [ ] App listing created
- [ ] Privacy policy URL provided
- [ ] App Review notes explain Family Controls
- [ ] Screenshots uploaded
- [ ] Description complete

---

## Quick Reference

### Bundle ID Format
```
com.yourcompany.appname
```

### App Group Format
```
group.com.yourcompany.appname
```

### Required Capabilities
- Family Controls
- App Groups

### Required iOS Version
- iOS 16.0+ (minimum)

### Testing Requirement
- Physical iPhone (simulator not supported)

### Key Files
- `ios/Runner/Runner.entitlements`
- `ios/Runner/Info.plist`
- `ios/Runner.xcodeproj/project.pbxproj`

### Developer Portal Links
- [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Documentation](https://developer.apple.com/documentation/familycontrols)

---

## Additional Resources

### Official Documentation
- [Family Controls Framework](https://developer.apple.com/documentation/familycontrols)
- [ManagedSettings Framework](https://developer.apple.com/documentation/managedsettings)
- [DeviceActivity Framework](https://developer.apple.com/documentation/deviceactivity)
- [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)

### Apple Developer Forums
- [Family Controls Discussion](https://developer.apple.com/forums/tags/family-controls)
- [Screen Time API](https://developer.apple.com/forums/tags/screen-time)

### Support
- [Apple Developer Support](https://developer.apple.com/contact/)
- [Technical Support Incidents](https://developer.apple.com/support/technical/)

---

**Last Updated**: 2025-01-27
**Xcode Version**: 15.0+
**iOS Version**: 16.0+
