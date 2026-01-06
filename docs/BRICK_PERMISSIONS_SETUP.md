# Brick App Features - Permissions & Setup Guide

This document provides detailed instructions for setting up all required permissions and configurations needed to implement Brick-like features in Flutter.

## Table of Contents

1. [iOS Setup](#ios-setup)
2. [Android Setup](#android-setup)
3. [Permission Request Flows](#permission-request-flows)
4. [Troubleshooting](#troubleshooting)
5. [Testing](#testing)

---

## iOS Setup

### 1. Family Controls Framework

#### Required Capabilities

**Step 1: Add Capability in Xcode**

1. Open your project in Xcode
2. Select your target (`Runner`)
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Family Controls**

**Step 2: Configure Entitlements**

Edit `ios/Runner/Runner.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.family-controls</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourapp.brick</string>
    </array>
</dict>
</plist>
```

**Step 3: Add App Group**

1. In Xcode, go to **Signing & Capabilities**
2. Click **+ Capability** → **App Groups**
3. Add your app group identifier (e.g., `group.com.yourapp.brick`)
4. Ensure it matches the one in `Runner.entitlements`

**Step 4: Update Info.plist**

Add usage description in `ios/Runner/Info.plist`:

```xml
<key>NSFamilyControlsUsageDescription</key>
<string>We need access to Family Controls to help you block distracting apps and focus on what matters.</string>
```

#### Authorization Request

**Native Swift Code:**

```swift
// ios/Runner/RestrictionEnginePlugin.swift
import FamilyControls
import ManagedSettings

@available(iOS 15.0, *)
class RestrictionEnginePlugin: NSObject, FlutterPlugin {
    private let authorizationCenter = AuthorizationCenter.shared
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        authorizationCenter.requestAuthorization { result in
            DispatchQueue.main.async {
                switch result {
                case .approved:
                    completion(true)
                case .denied:
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
}
```

**Flutter Code:**

```dart
// lib/platform/restriction_engine/ios/ios_restriction_engine.dart
Future<bool> requestFamilyControlsAuthorization() async {
  try {
    final bool granted = await _channel.invokeMethod('requestFamilyControlsAuthorization');
    return granted;
  } on PlatformException catch (e) {
    print('Error: ${e.message}');
    return false;
  }
}
```

**Important Notes:**
- ⚠️ **Cannot be tested in iOS Simulator** - requires physical device
- ⚠️ **One-time approval** - user must approve in Settings if denied
- ⚠️ **Requires iOS 15.0+**

### 2. Notification Permissions

**Info.plist Entry:**

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>We need notification access to filter and manage your notifications during focus mode.</string>
```

**Request Permission:**

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestNotificationPermission() async {
  final status = await Permission.notification.request();
  return status.isGranted;
}
```

### 3. Location Permissions (Optional)

**Info.plist Entry:**

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location to automatically activate focus mode when you arrive at work or home.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We use your location to automatically activate focus mode based on your location.</string>
```

**Request Permission:**

```dart
Future<bool> requestLocationPermission() async {
  final status = await Permission.locationWhenInUse.request();
  return status.isGranted;
}
```

---

## Android Setup

### 1. Usage Stats Permission

#### Required Permission

**AndroidManifest.xml:**

```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" />
```

#### Request Flow

**Step 1: Check Permission Status**

```kotlin
// android/app/src/main/kotlin/com/wintheyear/win_flutter/MainActivity.kt
import android.app.AppOpsManager
import android.content.Context
import android.provider.Settings

fun hasUsageStatsPermission(context: Context): Boolean {
    val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    val mode = appOps.checkOpNoThrow(
        AppOpsManager.OPSTR_GET_USAGE_STATS,
        android.os.Process.myUid(),
        context.packageName
    )
    return mode == AppOpsManager.MODE_ALLOWED
}
```

**Step 2: Open Settings**

```kotlin
fun openUsageStatsSettings(context: Context) {
    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
    context.startActivity(intent)
}
```

**Step 3: Flutter Integration**

```dart
// lib/platform/restriction_engine/android/android_restriction_engine.dart
Future<bool> requestUsageStatsPermission() async {
  try {
    // Check if already granted
    final bool granted = await _channel.invokeMethod('hasUsageStatsPermission');
    if (granted) return true;
    
    // Open settings
    await _channel.invokeMethod('openUsageStatsSettings');
    
    // Return false - user must grant manually
    return false;
  } on PlatformException catch (e) {
    print('Error: ${e.message}');
    return false;
  }
}

// Check permission status after user returns from settings
Future<bool> checkUsageStatsPermission() async {
  try {
    return await _channel.invokeMethod('hasUsageStatsPermission');
  } on PlatformException catch (e) {
    return false;
  }
}
```

**Step 4: UI Flow**

```dart
// lib/features/focus/ui/permission_request_screen.dart
class UsageStatsPermissionScreen extends StatefulWidget {
  @override
  _UsageStatsPermissionScreenState createState() => _UsageStatsPermissionScreenState();
}

class _UsageStatsPermissionScreenState extends State<UsageStatsPermissionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Permission Required')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.settings, size: 64, color: Colors.blue),
            SizedBox(height: 24),
            Text(
              'Usage Stats Permission Required',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Text(
              'To track app usage and enforce restrictions, we need access to Usage Stats.',
            ),
            SizedBox(height: 8),
            Text(
              'Steps:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text('1. Tap "Open Settings" below'),
            Text('2. Find "Brick" or "Win Flutter" in the list'),
            Text('3. Toggle the switch to enable'),
            Text('4. Return to this app'),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await _openSettings();
                // Check permission when user returns
                Future.delayed(Duration(seconds: 1), () {
                  _checkPermission();
                });
              },
              child: Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _openSettings() async {
    final androidEngine = AndroidRestrictionEngine();
    await androidEngine.requestUsageStatsPermission();
  }
  
  Future<void> _checkPermission() async {
    final androidEngine = AndroidRestrictionEngine();
    final granted = await androidEngine.checkUsageStatsPermission();
    
    if (granted) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission not granted. Please try again.')),
      );
    }
  }
}
```

**Important Notes:**
- ⚠️ **Cannot be granted programmatically** - user must enable in Settings
- ⚠️ **Requires Android 5.0+ (API 21+)**
- ⚠️ **User must manually enable** - guide them through the process

### 2. Accessibility Service Permission

#### Required Configuration

**Step 1: Create Accessibility Service**

```kotlin
// android/app/src/main/kotlin/com/wintheyear/win_flutter/focus/FocusAccessibilityService.kt
package com.wintheyear.win_flutter.focus

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.util.Log

class FocusAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "FocusAccessibilityService"
    }
    
    private val blockedPackages = mutableSetOf<String>()
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility service connected")
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event?.let {
            val packageName = it.packageName?.toString()
            if (packageName != null && blockedPackages.contains(packageName)) {
                Log.d(TAG, "Blocking app: $packageName")
                performGlobalAction(GLOBAL_ACTION_BACK)
            }
        }
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }
    
    fun setBlockedPackages(packages: Set<String>) {
        blockedPackages.clear()
        blockedPackages.addAll(packages)
        Log.d(TAG, "Blocked packages updated: $packages")
    }
}
```

**Step 2: Create Service Configuration**

Create `android/app/src/main/res/xml/accessibility_service_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/accessibility_service_description"
    android:accessibilityEventTypes="typeAllMask"
    android:accessibilityFlags="flagDefault"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="100"
    android:canRetrieveWindowContent="true"
    android:settingsActivity="com.wintheyear.win_flutter.MainActivity" />
```

**Step 3: Add String Resource**

`android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="accessibility_service_description">
        Brick uses accessibility services to help you stay focused by blocking distracting apps.
    </string>
</resources>
```

**Step 4: Register Service in Manifest**

`android/app/src/main/AndroidManifest.xml`:

```xml
<service
    android:name=".focus.FocusAccessibilityService"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService" />
    </intent-filter>
    <meta-data
        android:name="android.accessibilityservice"
        android:resource="@xml/accessibility_service_config" />
</service>
```

**Step 5: Request Permission**

```kotlin
fun hasAccessibilityPermission(context: Context): Boolean {
    val accessibilityServices = Settings.Secure.getString(
        context.contentResolver,
        Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
    )
    val packageName = context.packageName
    return accessibilityServices?.contains(packageName) == true
}

fun openAccessibilitySettings(context: Context) {
    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
    context.startActivity(intent)
}
```

**Step 6: Flutter Integration**

```dart
Future<bool> requestAccessibilityPermission() async {
  try {
    final bool granted = await _channel.invokeMethod('hasAccessibilityPermission');
    if (granted) return true;
    
    await _channel.invokeMethod('openAccessibilitySettings');
    return false; // User must enable manually
  } on PlatformException catch (e) {
    return false;
  }
}
```

**Important Notes:**
- ⚠️ **User must enable manually** in Accessibility settings
- ⚠️ **Requires Android 4.0+ (API 14+)**
- ⚠️ **Can be disabled by user** at any time

### 3. Notification Listener Permission

#### Required Configuration

**Step 1: Create Notification Listener Service**

```kotlin
// android/app/src/main/kotlin/com/wintheyear/win_flutter/focus/FocusNotificationService.kt
package com.wintheyear.win_flutter.focus

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class FocusNotificationService : NotificationListenerService() {
    private val allowedPackages = mutableSetOf<String>()
    
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn?.let {
            val packageName = it.packageName
            if (!allowedPackages.contains(packageName)) {
                cancelNotification(sbn.key)
            }
        }
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Handle notification removal
    }
    
    fun setAllowedPackages(packages: Set<String>) {
        allowedPackages.clear()
        allowedPackages.addAll(packages)
    }
}
```

**Step 2: Register in Manifest**

```xml
<service
    android:name=".focus.FocusNotificationService"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

**Step 3: Request Permission**

```kotlin
fun openNotificationListenerSettings(context: Context) {
    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
    context.startActivity(intent)
}

fun hasNotificationListenerPermission(context: Context): Boolean {
    val enabledListeners = Settings.Secure.getString(
        context.contentResolver,
        "enabled_notification_listeners"
    )
    val packageName = context.packageName
    return enabledListeners?.contains(packageName) == true
}
```

**Important Notes:**
- ⚠️ **User must enable manually** in Notification access settings
- ⚠️ **Requires Android 4.3+ (API 18+)**

### 4. Phone & SMS Permissions (Optional)

**AndroidManifest.xml:**

```xml
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.SEND_SMS" />
```

**Request Permissions:**

```dart
Future<Map<String, bool>> requestPhonePermissions() async {
  final phoneStatus = await Permission.phone.request();
  final smsStatus = await Permission.sms.request();
  
  return {
    'phone': phoneStatus.isGranted,
    'sms': smsStatus.isGranted,
  };
}
```

**Important Notes:**
- ⚠️ **READ_PHONE_STATE** - Dangerous permission, requires runtime request
- ⚠️ **READ_SMS** - Dangerous permission, requires runtime request
- ⚠️ **SEND_SMS** - Dangerous permission, requires runtime request

---

## Permission Request Flows

### Complete Onboarding Flow

```dart
// lib/features/focus/ui/permission_onboarding_screen.dart
class PermissionOnboardingScreen extends StatefulWidget {
  @override
  _PermissionOnboardingScreenState createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen> {
  final List<PermissionStep> _steps = [];
  int _currentStep = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeSteps();
  }
  
  void _initializeSteps() {
    if (Platform.isIOS) {
      _steps.addAll([
        PermissionStep(
          title: 'Family Controls',
          description: 'We need access to Family Controls to block distracting apps.',
          icon: Icons.family_restroom,
          onRequest: () => _requestFamilyControls(),
        ),
        PermissionStep(
          title: 'Notifications',
          description: 'Allow us to manage your notifications during focus mode.',
          icon: Icons.notifications,
          onRequest: () => _requestNotifications(),
        ),
      ]);
    } else {
      _steps.addAll([
        PermissionStep(
          title: 'Usage Stats',
          description: 'We need access to track which apps you use.',
          icon: Icons.analytics,
          onRequest: () => _requestUsageStats(),
          requiresSettings: true,
        ),
        PermissionStep(
          title: 'Accessibility Service',
          description: 'Enable accessibility to block distracting apps.',
          icon: Icons.accessibility_new,
          onRequest: () => _requestAccessibility(),
          requiresSettings: true,
        ),
        PermissionStep(
          title: 'Notification Access',
          description: 'Allow us to filter your notifications.',
          icon: Icons.notifications_off,
          onRequest: () => _requestNotificationListener(),
          requiresSettings: true,
        ),
      ]);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_currentStep >= _steps.length) {
      return _buildCompletionScreen();
    }
    
    final step = _steps[_currentStep];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Permissions'),
        leading: _currentStep > 0 
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentStep + 1) / _steps.length,
            ),
            SizedBox(height: 32),
            Icon(step.icon, size: 80, color: Theme.of(context).primaryColor),
            SizedBox(height: 24),
            Text(
              step.title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              step.description,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            if (step.requiresSettings) ...[
              _buildSettingsInstructions(),
              SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: () => _handleStep(step),
              child: Text(step.requiresSettings ? 'Open Settings' : 'Grant Permission'),
            ),
            if (_currentStep < _steps.length - 1)
              TextButton(
                onPressed: () => setState(() => _currentStep++),
                child: Text('Skip for now'),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingsInstructions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to enable:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text('1. Tap "Open Settings" below'),
            Text('2. Find "${_steps[_currentStep].title}"'),
            Text('3. Toggle the switch to enable'),
            Text('4. Return to this app'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCompletionScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 80, color: Colors.green),
              SizedBox(height: 24),
              Text(
                'Setup Complete!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 16),
              Text(
                'You\'re all set to start using focus mode.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
                child: Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _handleStep(PermissionStep step) async {
    final granted = await step.onRequest();
    
    if (granted || step.requiresSettings) {
      // Move to next step after a delay (for settings-based permissions)
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _currentStep++);
        }
      });
    }
  }
  
  Future<bool> _requestFamilyControls() async {
    final iosEngine = IOSRestrictionEngine();
    return await iosEngine.requestFamilyControlsAuthorization();
  }
  
  Future<bool> _requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
  
  Future<bool> _requestUsageStats() async {
    final androidEngine = AndroidRestrictionEngine();
    await androidEngine.requestUsageStatsPermission();
    // Check after user returns
    await Future.delayed(Duration(seconds: 1));
    return await androidEngine.checkUsageStatsPermission();
  }
  
  Future<bool> _requestAccessibility() async {
    final androidEngine = AndroidRestrictionEngine();
    await androidEngine.requestAccessibilityPermission();
    await Future.delayed(Duration(seconds: 1));
    return await androidEngine.checkAccessibilityPermission();
  }
  
  Future<bool> _requestNotificationListener() async {
    final androidEngine = AndroidRestrictionEngine();
    await androidEngine.requestNotificationListenerPermission();
    await Future.delayed(Duration(seconds: 1));
    return await androidEngine.checkNotificationListenerPermission();
  }
}

class PermissionStep {
  final String title;
  final String description;
  final IconData icon;
  final Future<bool> Function() onRequest;
  final bool requiresSettings;
  
  PermissionStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.onRequest,
    this.requiresSettings = false,
  });
}
```

---

## Troubleshooting

### iOS Issues

#### Family Controls Authorization Fails

**Symptoms:**
- Authorization request returns false
- User sees error message

**Solutions:**
1. **Check Entitlements**: Ensure `com.apple.developer.family-controls` is in `Runner.entitlements`
2. **Check App Group**: Verify app group is configured in Xcode
3. **Physical Device**: Must test on physical device, not simulator
4. **iOS Version**: Requires iOS 15.0 or later
5. **User Settings**: User may have denied in Settings → Screen Time → Family Controls

**Debug Steps:**
```swift
// Check authorization status
let status = AuthorizationCenter.shared.authorizationStatus
print("Authorization status: \(status)")
```

#### Apps Not Blocking

**Symptoms:**
- Apps are selected but not blocked
- ManagedSettingsStore not working

**Solutions:**
1. **Verify Authorization**: Ensure authorization is approved
2. **Check App Tokens**: Verify tokens are valid
3. **App Group**: Ensure app group is shared between app and extension
4. **Background Execution**: App may need background modes enabled

### Android Issues

#### Usage Stats Permission Not Working

**Symptoms:**
- Permission check returns false
- Cannot track app usage

**Solutions:**
1. **Manual Check**: Verify user enabled in Settings → Apps → Special access → Usage access
2. **Package Name**: Ensure package name matches exactly
3. **API Level**: Requires Android 5.0+ (API 21+)
4. **Restart App**: May need to restart app after granting permission

**Debug Code:**
```kotlin
fun debugUsageStatsPermission(context: Context) {
    val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    val mode = appOps.checkOpNoThrow(
        AppOpsManager.OPSTR_GET_USAGE_STATS,
        android.os.Process.myUid(),
        context.packageName
    )
    Log.d("Permission", "Mode: $mode")
    Log.d("Permission", "Package: ${context.packageName}")
}
```

#### Accessibility Service Not Blocking Apps

**Symptoms:**
- Service is enabled but apps aren't blocked
- Service not receiving events

**Solutions:**
1. **Service Enabled**: Verify in Settings → Accessibility
2. **Configuration**: Check `accessibility_service_config.xml`
3. **Package Names**: Ensure blocked packages list is updated
4. **Service Restart**: May need to restart service after changes

**Debug Code:**
```kotlin
override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    Log.d("Accessibility", "Event: ${event?.eventType}")
    Log.d("Accessibility", "Package: ${event?.packageName}")
    Log.d("Accessibility", "Blocked: ${blockedPackages.contains(event?.packageName)}")
}
```

#### Notification Listener Not Filtering

**Symptoms:**
- Notifications still appear
- Service not receiving notifications

**Solutions:**
1. **Service Enabled**: Verify in Settings → Notification access
2. **Service Running**: Check if service is bound
3. **Package List**: Ensure allowed packages list is set
4. **Permissions**: Verify notification permission is granted

---

## Testing

### iOS Testing Checklist

- [ ] Test on physical device (not simulator)
- [ ] Test Family Controls authorization flow
- [ ] Test app blocking functionality
- [ ] Test with different iOS versions (15.0+)
- [ ] Test app group sharing
- [ ] Test background execution
- [ ] Test notification filtering

### Android Testing Checklist

- [ ] Test on multiple Android versions (5.0+)
- [ ] Test Usage Stats permission flow
- [ ] Test Accessibility Service setup
- [ ] Test Notification Listener setup
- [ ] Test app blocking functionality
- [ ] Test background execution
- [ ] Test battery impact
- [ ] Test on different device manufacturers

### Test Scenarios

1. **First Launch**: All permissions should be requested
2. **Permission Denied**: App should handle gracefully
3. **Permission Revoked**: App should detect and re-request
4. **App Restart**: Permissions should persist
5. **Background Mode**: Restrictions should work when app is closed
6. **Multiple Profiles**: Switching profiles should work correctly

---

## Additional Resources

### Official Documentation

- **iOS Family Controls**: https://developer.apple.com/documentation/familycontrols
- **Android Usage Stats**: https://developer.android.com/reference/android/app/usage/UsageStatsManager
- **Android Accessibility**: https://developer.android.com/reference/android/accessibilityservice/AccessibilityService
- **Flutter Platform Channels**: https://docs.flutter.dev/platform-integration/platform-channels

### Useful Packages

- **permission_handler**: https://pub.dev/packages/permission_handler
- **device_info_plus**: https://pub.dev/packages/device_info_plus
- **shared_preferences**: https://pub.dev/packages/shared_preferences

### Support Links

- **Brick App Website**: https://getbrick.app/
- **iOS Developer Forums**: https://developer.apple.com/forums/
- **Android Developer Forums**: https://developer.android.com/community
