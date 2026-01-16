# NFC Setup Checklist (iOS + Android)

This guide is for a college student who wants a clear, step‑by‑step path to fix “missing entitlements” and confirm NFC works. It’s detailed on purpose. Follow it top‑to‑bottom once, then use it as a checklist later.

## Quick summary (what usually fixes it)

- iOS: Enable **NFC Tag Reading** capability in Xcode for the `Runner` target.
- iOS: Keep `NFCReaderUsageDescription` in `Info.plist`.
- iOS: Test on a **real device** (CoreNFC does **not** work on the simulator).
- Android: Ensure `android.permission.NFC` and `android.hardware.nfc` are in the manifest.

If you do those four things and still get errors, keep reading.

---

## Part 1: iOS (CoreNFC)

### 1) Confirm your device is CoreNFC‑capable

- You must use a **physical iPhone** that supports NFC tag reading.
- The iOS Simulator **cannot** scan NFC tags.
- If you’re unsure: any iPhone 7 or newer supports NFC tag reading, but it still must be a real device.

### 2) Open the iOS project in Xcode

- In the Flutter repo, open:
  - `ios/Runner.xcworkspace`
- Do not open `Runner.xcodeproj` directly. Use the workspace.

### 3) Select the correct target

In Xcode:
- Click the project navigator (left sidebar).
- Click **Runner** at the top (the project).
- In the main panel, select the **Runner** target (not the project).

You should see tabs like **General**, **Signing & Capabilities**, **Info**, etc.

### 4) Enable NFC Tag Reading capability

This is the most common missing entitlements issue.

- Go to **Signing & Capabilities**.
- Click **+ Capability**.
- Search for **NFC Tag Reading**.
- Add it to the Runner target.

After adding it, you should see:
- A new “NFC Tag Reading” section in the capabilities list.
- An entitlement file update (Xcode handles it).

If you don’t see the capability, check:
- You selected the **Runner** target (not the project).
- You opened the `.xcworkspace`.

### 5) Confirm the entitlement file exists

Xcode should create or update something like:
- `ios/Runner/Runner.entitlements`

Open it and verify it contains:

```
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
  <string>NDEF</string>
</array>
```

If it is missing:
- Remove the NFC capability and re‑add it.
- Make sure you are editing the Runner target.

### 6) Confirm Info.plist has NFC usage text

Open `ios/Runner/Info.plist` and verify you have:

```
<key>NFCReaderUsageDescription</key>
<string>...</string>
```

This message is shown to the user the first time NFC is used. If it’s missing, the app can crash or be rejected by iOS.

### 7) Clean + rebuild

Sometimes Xcode keeps old build artifacts:

1. In a terminal at the repo root:
   - `flutter clean`
   - `flutter pub get`
2. Back in Xcode:
   - **Product → Clean Build Folder** (hold Option to see it)
3. Run again on device.

### 8) Signs you’re good

When you start scanning:
- iOS shows the native **“Ready to Scan”** sheet.
- No entitlement errors appear in the Xcode console.
- The tag is read and the app updates.

If you still see **“missing entitlements”**:
- It almost always means the **capability is not attached to the exact target** you built.
- Double‑check Step 3 and Step 4.

---

## Part 2: Android

### 1) Confirm manifest permissions

Open `android/app/src/main/AndroidManifest.xml`. You should have:

```
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="false" />
```

This allows NFC access and makes it optional for installs.

### 2) Confirm NFC is on in system settings

- Open device settings → search “NFC” → turn it on.
- Some Android devices hide NFC under “Connected devices” or “More connections.”

### 3) Test on real device

Android emulators usually don’t support real NFC tags.

### 4) Signs you’re good

- The app goes to “Scanning”.
- The tag is discovered and content shows up.

---

## Part 3: In‑app sanity checks

### 1) Confirm you can open the scan screen

In the app:
- **Settings → NFC scan**

### 2) Use the debug simulation (optional)

In debug builds there’s a **“Simulate Result”** button. Use it to confirm the UI renders decoded NDEF records.

### 3) Test with an actual tag

Use **NFC Tools**:
1. Open NFC Tools.
2. Go to **Write** tab.
3. Add a **Text** record (e.g., “Hello NFC”).
4. Add a **URI** record (e.g., `https://example.com`).
5. Tap **Write** and place your NTAG215 on the phone.
6. Go back to the app and scan the tag.

---

## Troubleshooting: still failing?

### iOS: “missing entitlements”

Common causes:
- You added capability to the **project** instead of the **Runner target**.
- You opened `.xcodeproj` instead of `.xcworkspace`.
- You’re running from **Flutter tool** but changed capabilities in a different Xcode target.
- Xcode didn’t save the entitlements file. Remove + add the capability again.

What to try:
- Reopen the workspace.
- Select Runner target → **Signing & Capabilities** → ensure **NFC Tag Reading** is listed.
- Clean + rebuild.

### iOS: no scan sheet appears

Check:
- You are on a real device.
- NFC is supported on the device.
- The app has NFC permission prompt accepted.

### Android: nothing happens

Check:
- NFC is enabled in system settings.
- You are testing on a real device.

---

## Final checklist (printable)

- iOS physical device with NFC.
- Open `ios/Runner.xcworkspace`.
- Runner **target** selected.
- **NFC Tag Reading** capability enabled.
- `Runner.entitlements` includes `com.apple.developer.nfc.readersession.formats` with `NDEF`.
- `NFCReaderUsageDescription` exists in `Info.plist`.
- Clean + rebuild.
- Android manifest includes NFC permission + feature.
- Android NFC enabled in system settings.

If all boxes are checked and it still fails, paste the exact error message and I’ll help you debug it.
