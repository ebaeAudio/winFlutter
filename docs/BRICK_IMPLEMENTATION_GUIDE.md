# Brick App Features - Implementation Guide for Flutter

This document provides detailed implementation guides for integrating Brick-like features into a Flutter application.

## Table of Contents

1. [App Blocking & Restrictions](#app-blocking--restrictions)
2. [Focus Mode / Dumb Phone Mode](#focus-mode--dumb-phone-mode)
3. [Screen Time Management](#screen-time-management)
4. [Notification Management](#notification-management)
5. [Call & Message Filtering](#call--message-filtering)
6. [Customizable Profiles](#customizable-profiles)
7. [Usage Analytics](#usage-analytics)
8. [Permissions Setup](#permissions-setup)

---

## App Blocking & Restrictions

### iOS Implementation

#### Required Frameworks
- `FamilyControls` - For app selection and blocking
- `ManagedSettings` - For applying restrictions
- `DeviceActivity` - For monitoring device activity

#### Step 1: Add Capabilities

**In Xcode:**
1. Open your project in Xcode
2. Select your target → Signing & Capabilities
3. Add "Family Controls" capability
4. Add "Managed Settings" capability

**In `ios/Runner/Runner.entitlements`:**
```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourapp.brick</string>
</array>
```

#### Step 2: Request Authorization

```dart
// lib/platform/restriction_engine/ios/ios_restriction_engine.dart
import 'package:flutter/services.dart';

class IOSRestrictionEngine {
  static const MethodChannel _channel = MethodChannel('win_flutter/restriction_engine');
  
  Future<bool> requestAuthorization() async {
    try {
      final bool granted = await _channel.invokeMethod('requestFamilyControlsAuthorization');
      return granted;
    } on PlatformException catch (e) {
      print('Error requesting authorization: $e');
      return false;
    }
  }
}
```

**Native iOS Code (`ios/Runner/RestrictionEnginePlugin.swift`):**
```swift
import Flutter
import FamilyControls
import ManagedSettings

@available(iOS 15.0, *)
class RestrictionEnginePlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "win_flutter/restriction_engine",
            binaryMessenger: registrar.messenger()
        )
        let instance = RestrictionEnginePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestFamilyControlsAuthorization":
            requestAuthorization(result: result)
        case "blockApps":
            blockApps(call: call, result: result)
        case "unblockApps":
            unblockApps(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func requestAuthorization(result: @escaping FlutterResult) {
        AuthorizationCenter.shared.requestAuthorization { status in
            DispatchQueue.main.async {
                result(status == .approved)
            }
        }
    }
    
    private func blockApps(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let appTokens = args["appTokens"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: nil, details: nil))
            return
        }
        
        let store = ManagedSettingsStore()
        let applicationTokens = Set(appTokens.compactMap { ApplicationToken($0) })
        store.application.blockedApplications = applicationTokens
        result(true)
    }
    
    private func unblockApps(result: @escaping FlutterResult) {
        let store = ManagedSettingsStore()
        store.clearAllSettings()
        result(true)
    }
}
```

#### Step 3: Select Apps to Block

```dart
Future<List<String>> selectAppsToBlock() async {
  try {
    final List<dynamic> appTokens = await _channel.invokeMethod('selectApps');
    return appTokens.cast<String>();
  } on PlatformException catch (e) {
    print('Error selecting apps: $e');
    return [];
  }
}

Future<void> blockApps(List<String> appTokens) async {
  try {
    await _channel.invokeMethod('blockApps', {'appTokens': appTokens});
  } on PlatformException catch (e) {
    print('Error blocking apps: $e');
  }
}
```

### Android Implementation

#### Step 1: Add Permissions

**In `android/app/src/main/AndroidManifest.xml`:**
```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" />
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
<uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE" />
```

#### Step 2: Create Accessibility Service

**`android/app/src/main/kotlin/com/wintheyear/win_flutter/focus/FocusAccessibilityService.kt`:**
```kotlin
package com.wintheyear.win_flutter.focus

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.util.Log

class FocusAccessibilityService : AccessibilityService() {
    private val blockedPackages = mutableSetOf<String>()
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event?.let {
            val packageName = it.packageName?.toString()
            if (packageName != null && blockedPackages.contains(packageName)) {
                // Block the app by going back
                performGlobalAction(GLOBAL_ACTION_BACK)
                // Or show a blocking overlay
                showBlockingOverlay()
            }
        }
    }
    
    override fun onInterrupt() {}
    
    fun setBlockedPackages(packages: Set<String>) {
        blockedPackages.clear()
        blockedPackages.addAll(packages)
    }
    
    private fun showBlockingOverlay() {
        val intent = Intent(this, BlockingOverlayActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
```

#### Step 3: Accessibility Service Configuration

**`android/app/src/main/res/xml/accessibility_service_config.xml`:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/accessibility_service_description"
    android:packageNames="com.example.app1,com.example.app2"
    android:accessibilityEventTypes="typeAllMask"
    android:accessibilityFlags="flagDefault"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="100"
    android:canRetrieveWindowContent="true"
    android:settingsActivity="com.wintheyear.win_flutter.SettingsActivity" />
```

#### Step 4: Request Usage Stats Permission

```dart
// lib/platform/restriction_engine/android/android_restriction_engine.dart
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidRestrictionEngine {
  static const MethodChannel _channel = MethodChannel('win_flutter/restriction_engine');
  
  Future<bool> requestUsageStatsPermission() async {
    try {
      // Check if permission is granted
      final bool granted = await _channel.invokeMethod('hasUsageStatsPermission');
      if (granted) return true;
      
      // Open settings to grant permission
      final bool opened = await _channel.invokeMethod('openUsageStatsSettings');
      return opened;
    } on PlatformException catch (e) {
      print('Error requesting usage stats permission: $e');
      return false;
    }
  }
  
  Future<bool> requestAccessibilityPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('hasAccessibilityPermission');
      if (granted) return true;
      
      final bool opened = await _channel.invokeMethod('openAccessibilitySettings');
      return opened;
    } on PlatformException catch (e) {
      print('Error requesting accessibility permission: $e');
      return false;
    }
  }
  
  Future<void> blockApps(List<String> packageNames) async {
    try {
      await _channel.invokeMethod('blockApps', {'packageNames': packageNames});
    } on PlatformException catch (e) {
      print('Error blocking apps: $e');
    }
  }
}
```

**Native Android Code (`android/app/src/main/kotlin/com/wintheyear/win_flutter/MainActivity.kt`):**
```kotlin
import android.provider.Settings
import android.content.Intent
import android.app.usage.UsageStatsManager
import android.content.Context

class MainActivity: FlutterActivity() {
    private val CHANNEL = "win_flutter/restriction_engine"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "openUsageStatsSettings" -> {
                    openUsageStatsSettings()
                    result.success(true)
                }
                "hasAccessibilityPermission" -> {
                    result.success(hasAccessibilityPermission())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "blockApps" -> {
                    val packageNames = call.argument<List<String>>("packageNames")
                    blockApps(packageNames ?: emptyList())
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }
    
    private fun openUsageStatsSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        startActivity(intent)
    }
    
    private fun hasAccessibilityPermission(): Boolean {
        val accessibilityServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return accessibilityServices?.contains(packageName) == true
    }
    
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
    }
    
    private fun blockApps(packageNames: List<String>) {
        val prefs = getSharedPreferences("focus_settings", Context.MODE_PRIVATE)
        prefs.edit().putStringSet("blocked_apps", packageNames.toSet()).apply()
        
        // Notify accessibility service
        val serviceIntent = Intent(this, FocusAccessibilityService::class.java)
        serviceIntent.putStringArrayListExtra("blocked_packages", ArrayList(packageNames))
        startService(serviceIntent)
    }
}
```

---

## Focus Mode / Dumb Phone Mode

### Implementation Strategy

#### Step 1: Create Focus Mode State Manager

```dart
// lib/features/focus/focus_mode_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/restriction_engine/restriction_engine.dart';

class FocusModeState {
  final bool isActive;
  final List<String> blockedApps;
  final List<String> allowedApps;
  final DateTime? startTime;
  final DateTime? endTime;
  
  FocusModeState({
    this.isActive = false,
    this.blockedApps = const [],
    this.allowedApps = const [],
    this.startTime,
    this.endTime,
  });
  
  FocusModeState copyWith({
    bool? isActive,
    List<String>? blockedApps,
    List<String>? allowedApps,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return FocusModeState(
      isActive: isActive ?? this.isActive,
      blockedApps: blockedApps ?? this.blockedApps,
      allowedApps: allowedApps ?? this.allowedApps,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class FocusModeNotifier extends StateNotifier<FocusModeState> {
  final RestrictionEngine restrictionEngine;
  
  FocusModeNotifier(this.restrictionEngine) : super(FocusModeState());
  
  Future<void> activateFocusMode({
    required List<String> blockedApps,
    List<String>? allowedApps,
    DateTime? endTime,
  }) async {
    try {
      await restrictionEngine.blockApps(blockedApps);
      
      state = state.copyWith(
        isActive: true,
        blockedApps: blockedApps,
        allowedApps: allowedApps ?? [],
        startTime: DateTime.now(),
        endTime: endTime,
      );
    } catch (e) {
      print('Error activating focus mode: $e');
    }
  }
  
  Future<void> deactivateFocusMode() async {
    try {
      await restrictionEngine.unblockApps();
      
      state = state.copyWith(
        isActive: false,
        startTime: null,
        endTime: null,
      );
    } catch (e) {
      print('Error deactivating focus mode: $e');
    }
  }
  
  Future<void> checkScheduledEnd() async {
    if (state.isActive && state.endTime != null) {
      if (DateTime.now().isAfter(state.endTime!)) {
        await deactivateFocusMode();
      }
    }
  }
}

final focusModeProvider = StateNotifierProvider<FocusModeNotifier, FocusModeState>((ref) {
  final restrictionEngine = ref.watch(restrictionEngineProvider);
  return FocusModeNotifier(restrictionEngine);
});
```

#### Step 2: Create Focus Mode UI

```dart
// lib/features/focus/ui/focus_mode_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'focus_mode_provider.dart';

class FocusModeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusMode = ref.watch(focusModeProvider);
    final focusModeNotifier = ref.read(focusModeProvider.notifier);
    
    return Scaffold(
      appBar: AppBar(title: Text('Focus Mode')),
      body: Column(
        children: [
          if (focusMode.isActive)
            _ActiveFocusModeCard(
              startTime: focusMode.startTime!,
              endTime: focusMode.endTime,
              onDeactivate: () => focusModeNotifier.deactivateFocusMode(),
            )
          else
            _InactiveFocusModeCard(
              onActivate: () => _showActivationDialog(context, ref),
            ),
          
          SizedBox(height: 24),
          
          _BlockedAppsList(blockedApps: focusMode.blockedApps),
          
          SizedBox(height: 24),
          
          _AllowedAppsList(allowedApps: focusMode.allowedApps),
        ],
      ),
    );
  }
  
  void _showActivationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _FocusModeActivationDialog(),
    );
  }
}

class _ActiveFocusModeCard extends StatelessWidget {
  final DateTime startTime;
  final DateTime? endTime;
  final VoidCallback onDeactivate;
  
  const _ActiveFocusModeCard({
    required this.startTime,
    this.endTime,
    required this.onDeactivate,
  });
  
  @override
  Widget build(BuildContext context) {
    final duration = endTime != null 
        ? endTime!.difference(DateTime.now())
        : DateTime.now().difference(startTime);
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Focus Mode Active',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            Text('Started: ${_formatTime(startTime)}'),
            if (endTime != null)
              Text('Ends: ${_formatTime(endTime!)}'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: onDeactivate,
              child: Text('Deactivate'),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
```

---

## Screen Time Management

### Implementation

#### Step 1: Track App Usage

**iOS (`ios/Runner/RestrictionEnginePlugin.swift`):**
```swift
import DeviceActivity

func getAppUsage(result: @escaping FlutterResult) {
    let center = DeviceActivityCenter()
    let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59),
        repeats: true
    )
    
    // Monitor app usage
    center.startMonitoring(
        with: DeviceActivityName("usage"),
        during: schedule
    )
    
    // Get usage data
    let store = ManagedSettingsStore()
    // Usage data is available through DeviceActivity framework
    result(true)
}
```

**Android:**
```kotlin
import android.app.usage.UsageStatsManager
import android.content.Context

fun getAppUsage(context: Context): Map<String, Long> {
    val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    val time = System.currentTimeMillis()
    val stats = usageStatsManager.queryUsageStats(
        UsageStatsManager.INTERVAL_DAILY,
        time - 86400000, // 24 hours ago
        time
    )
    
    val appUsage = mutableMapOf<String, Long>()
    stats.forEach { stat ->
        appUsage[stat.packageName] = stat.totalTimeInForeground
    }
    
    return appUsage
}
```

#### Step 2: Set Daily Limits

```dart
// lib/features/focus/screen_time_manager.dart
class ScreenTimeManager {
  final RestrictionEngine restrictionEngine;
  final Map<String, Duration> appLimits = {};
  
  Future<void> setDailyLimit(String appPackage, Duration limit) async {
    appLimits[appPackage] = limit;
    await _enforceLimit(appPackage, limit);
  }
  
  Future<void> _enforceLimit(String appPackage, Duration limit) async {
    // Check current usage
    final usage = await restrictionEngine.getAppUsage(appPackage);
    
    if (usage >= limit.inMilliseconds) {
      // Block the app
      await restrictionEngine.blockApps([appPackage]);
    }
  }
}
```

---

## Notification Management

### Implementation

#### Step 1: Request Notification Permission

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestNotificationPermission() async {
  final status = await Permission.notification.request();
  return status.isGranted;
}
```

#### Step 2: Filter Notifications

**Android - Notification Listener Service:**
```kotlin
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class FocusNotificationService : NotificationListenerService() {
    private val allowedPackages = mutableSetOf<String>()
    
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn?.let {
            val packageName = it.packageName
            if (!allowedPackages.contains(packageName)) {
                // Cancel the notification
                cancelNotification(sbn.key)
            }
        }
    }
    
    fun setAllowedPackages(packages: Set<String>) {
        allowedPackages.clear()
        allowedPackages.addAll(packages)
    }
}
```

**iOS - Notification Filtering:**
```swift
import UserNotifications

func filterNotifications(allowedCategories: Set<String>) {
    let center = UNUserNotificationCenter.current()
    
    center.getDeliveredNotifications { notifications in
        notifications.forEach { notification in
            if !allowedCategories.contains(notification.request.content.categoryIdentifier) {
                center.removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
            }
        }
    }
}
```

---

## Call & Message Filtering

### Implementation

#### Step 1: Request Phone Permissions

```dart
Future<bool> requestPhonePermissions() async {
  final phoneStatus = await Permission.phone.request();
  final smsStatus = await Permission.sms.request();
  
  return phoneStatus.isGranted && smsStatus.isGranted;
}
```

#### Step 2: Filter Calls

**Android:**
```kotlin
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager

class CallFilter(private val allowedContacts: Set<String>) : PhoneStateListener() {
    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                if (!allowedContacts.contains(phoneNumber)) {
                    // End the call
                    endCall()
                }
            }
        }
    }
    
    private fun endCall() {
        // Requires MODIFY_PHONE_STATE permission (system app only)
        // Alternative: Show blocking UI overlay
    }
}
```

---

## Customizable Profiles

### Implementation

```dart
// lib/features/focus/profile_manager.dart
class RestrictionProfile {
  final String id;
  final String name;
  final List<String> blockedApps;
  final List<String> allowedApps;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<int> activeDays; // 0=Sunday, 6=Saturday
  
  RestrictionProfile({
    required this.id,
    required this.name,
    this.blockedApps = const [],
    this.allowedApps = const [],
    this.startTime,
    this.endTime,
    this.activeDays = const [0, 1, 2, 3, 4, 5, 6],
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'blockedApps': blockedApps,
    'allowedApps': allowedApps,
    'startTime': startTime?.toString(),
    'endTime': endTime?.toString(),
    'activeDays': activeDays,
  };
  
  factory RestrictionProfile.fromJson(Map<String, dynamic> json) {
    return RestrictionProfile(
      id: json['id'],
      name: json['name'],
      blockedApps: List<String>.from(json['blockedApps'] ?? []),
      allowedApps: List<String>.from(json['allowedApps'] ?? []),
      startTime: json['startTime'] != null 
          ? TimeOfDay.fromDateTime(DateTime.parse(json['startTime']))
          : null,
      endTime: json['endTime'] != null
          ? TimeOfDay.fromDateTime(DateTime.parse(json['endTime']))
          : null,
      activeDays: List<int>.from(json['activeDays'] ?? []),
    );
  }
  
  bool isActiveNow() {
    final now = DateTime.now();
    final currentDay = now.weekday % 7;
    
    if (!activeDays.contains(currentDay)) return false;
    
    if (startTime != null && endTime != null) {
      final currentTime = TimeOfDay.fromDateTime(now);
      // Check if current time is within range
      // Implementation depends on your time comparison logic
    }
    
    return true;
  }
}

class ProfileManager {
  final List<RestrictionProfile> profiles = [];
  
  Future<void> saveProfile(RestrictionProfile profile) async {
    // Save to SharedPreferences or database
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getStringList('profiles') ?? [];
    profilesJson.add(jsonEncode(profile.toJson()));
    await prefs.setStringList('profiles', profilesJson);
  }
  
  Future<List<RestrictionProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getStringList('profiles') ?? [];
    return profilesJson.map((json) => 
      RestrictionProfile.fromJson(jsonDecode(json))
    ).toList();
  }
}
```

---

## Usage Analytics

### Implementation

```dart
// lib/features/focus/usage_analytics.dart
class UsageAnalytics {
  final Map<String, List<Duration>> dailyUsage = {};
  
  void recordAppUsage(String appPackage, Duration duration) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    dailyUsage.putIfAbsent(today, () => []).add(duration);
  }
  
  Duration getTotalUsageToday() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayUsage = dailyUsage[today] ?? [];
    return todayUsage.fold(Duration.zero, (sum, duration) => sum + duration);
  }
  
  Map<String, Duration> getAppUsageToday() {
    // Group by app package
    // Return map of app -> total duration
    return {};
  }
  
  List<DailyUsageData> getWeeklyUsage() {
    final weekAgo = DateTime.now().subtract(Duration(days: 7));
    final usage = <DailyUsageData>[];
    
    for (var i = 0; i < 7; i++) {
      final date = weekAgo.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final dayUsage = dailyUsage[dateStr] ?? [];
      final total = dayUsage.fold(Duration.zero, (sum, d) => sum + d);
      
      usage.add(DailyUsageData(
        date: date,
        totalDuration: total,
      ));
    }
    
    return usage;
  }
}

class DailyUsageData {
  final DateTime date;
  final Duration totalDuration;
  
  DailyUsageData({required this.date, required this.totalDuration});
}
```

---

## Permissions Setup

### Complete Permissions Checklist

#### iOS Permissions

1. **Family Controls Authorization**
   - Required for app blocking
   - One-time user approval
   - Cannot be tested in simulator

2. **Notification Permission**
   - Required for notification filtering
   - Requested at runtime

3. **Location Permission** (Optional)
   - For location-based profiles
   - `NSLocationWhenInUseUsageDescription` in Info.plist

#### Android Permissions

1. **Usage Stats Permission**
   - Required for tracking app usage
   - User must grant in Settings
   - Cannot be granted programmatically

2. **Accessibility Service Permission**
   - Required for app blocking
   - User must enable in Accessibility settings

3. **Notification Listener Permission**
   - Required for notification filtering
   - User must enable in Notification settings

4. **Phone Permission** (Optional)
   - For call filtering
   - `android.permission.READ_PHONE_STATE`

5. **SMS Permission** (Optional)
   - For message filtering
   - `android.permission.READ_SMS`

### Permission Request Flow

```dart
// lib/features/focus/permission_handler.dart
class PermissionHandler {
  static Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};
    
    // iOS Family Controls
    if (Platform.isIOS) {
      results['familyControls'] = await _requestFamilyControls();
    }
    
    // Android Usage Stats
    if (Platform.isAndroid) {
      results['usageStats'] = await _requestUsageStats();
      results['accessibility'] = await _requestAccessibility();
      results['notificationListener'] = await _requestNotificationListener();
    }
    
    // Common permissions
    results['notifications'] = await _requestNotifications();
    
    return results;
  }
  
  static Future<bool> _requestFamilyControls() async {
    // Implementation
    return false;
  }
  
  static Future<bool> _requestUsageStats() async {
    // Open settings
    return false;
  }
  
  static Future<bool> _requestAccessibility() async {
    // Open accessibility settings
    return false;
  }
  
  static Future<bool> _requestNotificationListener() async {
    // Open notification listener settings
    return false;
  }
  
  static Future<bool> _requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
```

---

## Testing Considerations

### iOS Testing
- **Physical Device Required**: Screen Time API doesn't work in simulator
- **TestFlight**: Use TestFlight for beta testing
- **Family Controls**: Requires real Apple ID with Family Sharing

### Android Testing
- **Multiple Devices**: Test on different Android versions
- **Permission Flows**: Test all permission request flows
- **Background Execution**: Test restrictions when app is closed

---

## Troubleshooting Common Issues

### iOS Issues

**Problem**: Family Controls authorization fails
- **Solution**: Ensure entitlements are properly configured
- **Solution**: Use physical device (not simulator)
- **Solution**: Check app group configuration

**Problem**: Apps not blocking
- **Solution**: Verify ManagedSettingsStore is properly initialized
- **Solution**: Check app tokens are valid

### Android Issues

**Problem**: Usage Stats permission not granted
- **Solution**: Guide user to Settings manually
- **Solution**: Show clear instructions in UI

**Problem**: Accessibility service not working
- **Solution**: Verify service is enabled in Settings
- **Solution**: Check service configuration XML

**Problem**: Battery drain
- **Solution**: Optimize background monitoring
- **Solution**: Use WorkManager for scheduled tasks

---

## Additional Resources

- [iOS Family Controls Documentation](https://developer.apple.com/documentation/familycontrols)
- [Android Usage Stats Guide](https://developer.android.com/reference/android/app/usage/UsageStatsManager)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [Permission Handler Plugin](https://pub.dev/packages/permission_handler)
