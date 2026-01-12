# iOS troubleshooting notes

## Launch crash in Simulator: `EXC_BAD_ACCESS` during plugin registration (e.g. `app_links`)

### Symptom
- Crash on launch on iOS Simulator with a stack that includes:
  - `AppLinksIosPlugin.register(with:)`
  - `GeneratedPluginRegistrant.registerWithRegistry`
  - `AppDelegate.application(_:didFinishLaunchingWithOptions:)`

### Root cause (most common in this repo)
This project uses **UIScene** (`UIApplicationSceneManifest`) and a **storyboard-defined `FlutterViewController`** (`UIMainStoryboardFile = Main`).

In that setup, the Flutter view controller (and its underlying engine / binary messenger) may **not** be ready during `AppDelegate.didFinishLaunching`.

Some plugins (like `app_links`) create method/event channels immediately in `register(with:)`. If plugin registration runs too early, channel creation can hit a **nil/invalid messenger** and crash with `EXC_BAD_ACCESS`.

### Correct fix
- **Do not** call `GeneratedPluginRegistrant.register(...)` in `AppDelegate.didFinishLaunching`.
- **Do** register plugins in `SceneDelegate.scene(_:willConnectTo:options:)` after `window?.rootViewController` is a `FlutterViewController`.

See:
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/SceneDelegate.swift`

### “Nuke from orbit” rebuild steps (when diagnosing)

```bash
cd /Users/evan.beyrer/workspace/winFlutter
flutter clean
rm -rf ios/build ios/Pods ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData
cd ios
pod repo update
pod install --repo-update
```

