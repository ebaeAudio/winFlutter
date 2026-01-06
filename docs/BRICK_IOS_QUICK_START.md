# iOS Setup - Quick Start Checklist

Quick reference checklist for setting up Brick app features on iOS.

## ✅ Pre-Flight Checklist

- [ ] Apple Developer Account ($99/year) - [developer.apple.com](https://developer.apple.com)
- [ ] Xcode 14.0+ installed
- [ ] Physical iPhone (iOS 16.0+) - **Simulator won't work!**
- [ ] USB cable to connect iPhone

## 🚀 5-Minute Setup

### 1. Developer Portal (5 min)

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. **Certificates, Identifiers & Profiles** → **Identifiers** → **App IDs**
3. Click **"+"** → Create App ID
4. Bundle ID: `com-wintheyear-winFlutter-dev` (or your bundle ID)
5. Enable capabilities:
   - ✅ **Family Controls**
   - ✅ **App Groups**
6. Click **Register**

### 2. Xcode Configuration (5 min)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target → **Signing & Capabilities** tab
3. **Team**: Select your Apple Developer team
4. **Bundle Identifier**: `com-wintheyear-winFlutter-dev`
5. ✅ Check **"Automatically manage signing"**

### 3. Add Capabilities (2 min)

1. Click **"+ Capability"** button
2. Add **Family Controls**
3. Add **App Groups**
4. In App Groups, click **"+"** → Enter: `group.com-wintheyear-winFlutter-dev`

### 4. Verify Files (1 min)

**Check `ios/Runner/Runner.entitlements`**:
```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com-wintheyear-winFlutter-dev</string>
</array>
```

**Check `ios/Runner/Info.plist`** has:
```xml
<key>NSFamilyControlsUsageDescription</key>
<string>Win Flutter needs access to Screen Time...</string>
```

### 5. Build & Test (2 min)

1. Connect iPhone via USB
2. Unlock iPhone
3. In Xcode, select your iPhone from device dropdown
4. Click **Play** button (▶️)
5. On iPhone: **Settings** → **General** → **VPN & Device Management** → Trust developer

## ⚠️ Critical Notes

### Must Use Physical Device
- ❌ **Simulator will NOT work**
- ✅ **Must use real iPhone**
- Family Controls API requires physical device

### iOS Version
- ✅ **iOS 16.0+ required**
- Check: Settings → General → About → Software Version

### Developer Mode (iOS 16+)
On iPhone:
1. Settings → Privacy & Security
2. Scroll to **Developer Mode**
3. Toggle **ON**
4. Restart iPhone

## 🔧 Troubleshooting

### "Family Controls authorization failed"
- ✅ Check entitlements file
- ✅ Verify App Groups matches everywhere
- ✅ Use physical device (not simulator)
- ✅ Check iOS version is 16.0+

### "Code signing failed"
- ✅ Select correct team in Xcode
- ✅ Enable "Automatically manage signing"
- ✅ Check bundle ID matches Developer Portal

### "Missing capability"
- ✅ Add Family Controls in Xcode
- ✅ Add App Groups in Xcode
- ✅ Enable in Developer Portal App ID

## 📋 Full Documentation

For detailed instructions, see:
- **[BRICK_IOS_XCODE_SETUP_GUIDE.md](./BRICK_IOS_XCODE_SETUP_GUIDE.md)** - Complete step-by-step guide
- **[BRICK_PERMISSIONS_SETUP.md](./BRICK_PERMISSIONS_SETUP.md)** - Permission details
- **[BRICK_IMPLEMENTATION_GUIDE.md](./BRICK_IMPLEMENTATION_GUIDE.md)** - Code implementation

## 🎯 Next Steps

After setup:
1. ✅ Test Family Controls authorization
2. ✅ Implement `startSession` in iOS plugin
3. ✅ Test app blocking on device
4. ✅ Add app selection UI

---

**Time Estimate**: ~15 minutes total
**Difficulty**: Medium (requires Apple Developer account)
