# Completing Brick Features in Flutter - Step-by-Step Guide

This guide shows you exactly how to complete the Brick app features using your existing Flutter codebase.

## ✅ What You Already Have

Your codebase already includes:
- ✅ Restriction engine abstraction (`RestrictionEngine`)
- ✅ Platform channels (`win_flutter/restriction_engine`)
- ✅ iOS plugin scaffold (`RestrictionEnginePlugin.swift`)
- ✅ Android plugin scaffold (`MainActivity.kt`)
- ✅ Focus mode UI (`FocusEntryScreen`, `FocusOnboardingScreen`)
- ✅ Domain models (`AppIdentifier`, `FocusFrictionSettings`)

## 🎯 What Needs to Be Completed

### Priority 1: Complete iOS App Blocking

Your `startSession` method in iOS is currently a no-op. Here's how to complete it:

#### Step 1: Update iOS Plugin

**File: `ios/Runner/RestrictionEnginePlugin.swift`**

Replace the `startSession` case with:

```swift
case "startSession":
  startSession(call: call, result: result)
```

Add this method:

```swift
#if canImport(FamilyControls) && canImport(ManagedSettings)
@available(iOS 16.0, *)
private func startSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
  guard let args = call.arguments as? [String: Any],
        let endsAtMillis = args["endsAtMillis"] as? Int64,
        let allowedApps = args["allowedApps"] as? [[String: Any]] else {
    result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
    return
  }
  
  // Convert Flutter app identifiers to ApplicationTokens
  // Note: iOS requires using FamilyActivityPicker to get tokens
  // For now, we'll use ManagedSettingsStore to block all apps except allowed ones
  
  let store = ManagedSettingsStore()
  
  // Get all installed apps (this is a simplified approach)
  // In production, you'd use FamilyActivityPicker to let user select apps
  var blockedTokens = Set<ApplicationToken>()
  
  // This is a placeholder - you'll need to implement app discovery
  // and convert bundle IDs to ApplicationTokens
  
  // For now, block everything except system apps
  // The proper way is to use FamilyActivityPicker in Flutter UI
  
  store.application.blockedApplications = blockedTokens
  
  // Store session end time
  let endsAt = Date(timeIntervalSince1970: Double(endsAtMillis) / 1000.0)
  UserDefaults.standard.set(endsAt, forKey: "focus_session_ends_at")
  
  result(nil)
}
#endif
```

#### Step 2: Add App Selection UI (iOS)

Create a native iOS view controller for app selection:

**File: `ios/Runner/AppPickerViewController.swift`** (new file)

```swift
#if canImport(FamilyControls)
import FamilyControls
import SwiftUI

@available(iOS 16.0, *)
struct AppPickerView: UIViewControllerRepresentable {
  @Binding var selectedTokens: Set<ApplicationToken>
  
  func makeUIViewController(context: Context) -> UIViewController {
    let picker = FamilyActivityPicker()
    picker.delegate = context.coordinator
    
    let vc = UIViewController()
    vc.view = picker.view
    return vc
  }
  
  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, FamilyActivityPickerDelegate {
    var parent: AppPickerView
    
    init(_ parent: AppPickerView) {
      self.parent = parent
    }
    
    func familyActivityPickerDidFinish(_ picker: FamilyActivityPicker) {
      // Handle selection
    }
  }
}
#endif
```

**Better Approach**: Use a Flutter UI with platform channel to show native picker:

```dart
// lib/features/focus/ui/app_picker_screen.dart
Future<Set<String>> selectAppsIOS() async {
  try {
    final List<dynamic> tokens = await _channel.invokeMethod('showAppPicker');
    return tokens.cast<String>().toSet();
  } catch (e) {
    print('Error selecting apps: $e');
    return {};
  }
}
```

Add to iOS plugin:

```swift
case "showAppPicker":
  showAppPicker(result: result)
```

```swift
#if canImport(FamilyControls)
@available(iOS 16.0, *)
private func showAppPicker(result: @escaping FlutterResult) {
  let picker = FamilyActivityPicker()
  // Present picker and return selected tokens
  // This requires UI presentation - you may want to use a Flutter method channel callback
}
#endif
```

### Priority 2: Complete Android App Blocking

Your Android implementation stores session data but doesn't actually block apps. Complete the Accessibility Service:

#### Step 1: Complete Accessibility Service

**File: `android/app/src/main/kotlin/com/wintheyear/win_flutter/focus/FocusAccessibilityService.kt`**

```kotlin
package com.wintheyear.win_flutter.focus

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import org.json.JSONArray

class FocusAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "FocusAccessibilityService"
        private const val PREFS_NAME = "focus_engine_prefs"
    }
    
    private val blockedPackages = mutableSetOf<String>()
    private var sessionActive = false
    private var sessionEndsAt: Long = 0
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility service connected")
        loadSessionData()
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!sessionActive) return
        
        event?.let {
            val packageName = it.packageName?.toString()
            if (packageName != null && shouldBlockApp(packageName)) {
                Log.d(TAG, "Blocking app: $packageName")
                blockApp(packageName)
            }
        }
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }
    
    private fun loadSessionData() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        sessionActive = prefs.getBoolean("active", false)
        sessionEndsAt = prefs.getLong("endsAtMillis", 0)
        
        val allowedAppsJson = prefs.getString("allowedAppsJson", "[]") ?: "[]"
        val allowedApps = try {
            JSONArray(allowedAppsJson).let { array ->
                (0 until array.length()).map { array.getString(it) }
            }
        } catch (e: Exception) {
            emptyList()
        }
        
        // Get all installed apps and block everything except allowed apps
        val pm = packageManager
        val installedPackages = pm.getInstalledPackages(0)
        
        blockedPackages.clear()
        installedPackages.forEach { packageInfo ->
            val packageName = packageInfo.packageName
            // Don't block system apps or our own app
            if (!isSystemApp(packageName) && 
                packageName != packageName && 
                !allowedApps.contains(packageName)) {
                blockedPackages.add(packageName)
            }
        }
        
        Log.d(TAG, "Loaded session: active=$sessionActive, blocked=${blockedPackages.size} apps")
    }
    
    private fun shouldBlockApp(packageName: String): Boolean {
        // Check if session is still active
        if (System.currentTimeMillis() > sessionEndsAt) {
            sessionActive = false
            return false
        }
        
        return blockedPackages.contains(packageName)
    }
    
    private fun blockApp(packageName: String) {
        // Method 1: Go back (simple but may not work for all apps)
        performGlobalAction(GLOBAL_ACTION_BACK)
        
        // Method 2: Show blocking overlay (better UX)
        showBlockingOverlay(packageName)
    }
    
    private fun showBlockingOverlay(packageName: String) {
        val intent = Intent(this, BlockingOverlayActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("blocked_package", packageName)
        }
        startActivity(intent)
    }
    
    private fun isSystemApp(packageName: String): Boolean {
        return try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
        } catch (e: Exception) {
            false
        }
    }
}
```

#### Step 2: Create Blocking Overlay Activity

**File: `android/app/src/main/kotlin/com/wintheyear/win_flutter/focus/BlockingOverlayActivity.kt`** (new file)

```kotlin
package com.wintheyear.win_flutter.focus

import android.app.Activity
import android.os.Bundle
import android.view.WindowManager
import android.widget.TextView

class BlockingOverlayActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Make it a system overlay
        window.setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)
        window.addFlags(WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH)
        
        val textView = TextView(this).apply {
            text = "This app is blocked during focus mode"
            textSize = 20f
            setPadding(40, 40, 40, 40)
        }
        
        setContentView(textView)
        
        // Auto-close after showing message
        finish()
    }
}
```

Register in `AndroidManifest.xml`:

```xml
<activity
    android:name=".focus.BlockingOverlayActivity"
    android:theme="@android:style/Theme.Translucent.NoTitleBar"
    android:excludeFromRecents="true"
    android:launchMode="singleInstance" />
```

### Priority 3: Add App Selection UI (Flutter)

Create a Flutter screen to select which apps to allow:

**File: `lib/features/focus/ui/app_selection_screen.dart`** (new file)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/focus/app_identifier.dart';

class AppSelectionScreen extends ConsumerStatefulWidget {
  final List<AppIdentifier> initialSelection;
  
  const AppSelectionScreen({
    super.key,
    this.initialSelection = const [],
  });
  
  @override
  ConsumerState<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends ConsumerState<AppSelectionScreen> {
  final Set<AppIdentifier> _selectedApps = {};
  
  @override
  void initState() {
    super.initState();
    _selectedApps.addAll(widget.initialSelection);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Allowed Apps'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selectedApps.toList()),
            child: Text('Done'),
          ),
        ],
      ),
      body: FutureBuilder<List<AppIdentifier>>(
        future: _loadInstalledApps(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final apps = snapshot.data ?? [];
          
          return ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              final isSelected = _selectedApps.contains(app);
              
              return CheckboxListTile(
                title: Text(app.displayName),
                subtitle: Text(app.bundleId),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedApps.add(app);
                    } else {
                      _selectedApps.remove(app);
                    }
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
  
  Future<List<AppIdentifier>> _loadInstalledApps() async {
    // Use platform channel to get installed apps
    // This requires adding a method to your platform channels
    try {
      final List<dynamic> apps = await _channel.invokeMethod('getInstalledApps');
      return apps.map((app) => AppIdentifier.fromJson(app)).toList();
    } catch (e) {
      print('Error loading apps: $e');
      return [];
    }
  }
}
```

### Priority 4: Add Usage Tracking

Add methods to track app usage:

**Flutter:**

```dart
// Add to RestrictionEngine interface
Future<Map<String, Duration>> getAppUsage({
  required DateTime startTime,
  required DateTime endTime,
});
```

**iOS:**

```swift
case "getAppUsage":
  getAppUsage(call: call, result: result)
```

```swift
#if canImport(DeviceActivity)
@available(iOS 16.0, *)
private func getAppUsage(call: FlutterMethodCall, result: @escaping FlutterResult) {
  // Use DeviceActivity framework to get usage data
  // This requires setting up DeviceActivityCenter
}
#endif
```

**Android:**

```kotlin
case "getAppUsage" -> {
  val args = call.arguments as? Map<*, *>
  val startTime = (args?.get("startTime") as? Number)?.toLong() ?: 0L
  val endTime = (args?.get("endTime") as? Number)?.toLong() ?: 0L
  
  val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
  val stats = usageStatsManager.queryUsageStats(
    UsageStatsManager.INTERVAL_DAILY,
    startTime,
    endTime
  )
  
  val usageMap = stats?.associate { 
    it.packageName to it.totalTimeInForeground 
  } ?: emptyMap()
  
  result.success(usageMap)
}
```

## 📋 Implementation Checklist

### iOS
- [ ] Complete `startSession` implementation
- [ ] Add app picker UI (native or Flutter)
- [ ] Implement app blocking with ManagedSettingsStore
- [ ] Add usage tracking with DeviceActivity
- [ ] Test on physical device (simulator won't work)

### Android
- [ ] Complete Accessibility Service implementation
- [ ] Create blocking overlay activity
- [ ] Add app discovery method
- [ ] Implement usage stats tracking
- [ ] Test on multiple Android versions

### Flutter
- [ ] Create app selection screen
- [ ] Add usage analytics UI
- [ ] Connect UI to restriction engine
- [ ] Add error handling
- [ ] Add loading states

## 🚀 Quick Start

1. **Start with iOS**: Complete the `startSession` method first
2. **Then Android**: Complete the Accessibility Service
3. **Add UI**: Create app selection screens
4. **Test**: Test on physical devices

## 📚 Reference Documentation

- See `BRICK_IMPLEMENTATION_GUIDE.md` for detailed code examples
- See `BRICK_PERMISSIONS_SETUP.md` for permission setup
- See `BRICK_APP_FEATURES.md` for feature overview

## 💡 Tips

1. **Test Early**: Test permission flows early - they're the hardest part
2. **Start Simple**: Get basic blocking working before adding analytics
3. **Use Your Existing Code**: Your abstraction is good - just fill in the implementations
4. **Platform Channels**: Your channel setup is correct - just add more methods

## 🐛 Common Issues

### iOS
- **Family Controls not working**: Check entitlements, use physical device
- **Apps not blocking**: Verify authorization, check app tokens

### Android
- **Accessibility not blocking**: Verify service is enabled
- **Overlay not showing**: Check window flags and permissions

Your Flutter architecture is solid - you just need to complete the native implementations!
