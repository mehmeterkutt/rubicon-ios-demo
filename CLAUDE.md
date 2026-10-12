# Rubicon iOS demo app

The iOS host app used to exercise the Rubicon analytics SDK by hand before a release, the
counterpart of `rubicon-team/rubicon-android-demo`. The SDK lives in `rubicon-team/rubicon-ios-sdk`;
its design is in Confluence (space SD, "Analytics SDK: iOS") and its implementation plan in the SDK
repository (`docs/implementation-plan.md`, phase 9 is this repository). This repository holds the
app, the fake backend and the manual checklist. Never log or display property values from the SDK's
log; the SDK's own rule applies to what the demo prints about it.

## Layout

| Path | What it is |
|---|---|
| `project.yml` | XcodeGen spec; `RubiconDemo.xcodeproj` is generated and never committed |
| `RubiconDemo/App` | `AppDelegate` (creates the SDK at launch), `SceneDelegate` (the window, the deep links), `DemoApp` (what the screens share), `Navigator` (UIKit pushes from SwiftUI) |
| `RubiconDemo/Config` | `DemoSettings` (every SDK setting, saved in `UserDefaults`, applied at the next launch), `HookPreset` (the `beforeSend` presets) |
| `RubiconDemo/SDK` | `EventFeed` (the `eventObserver`), `SdkLog` (the logger), `PersonStore` (what the app told the SDK) |
| `RubiconDemo/Net` | `ApiCalls` (the app's own `URLSession` with `RubiconNetworkObserver`), `FakeBackend` (the control endpoints) |
| `RubiconDemo/Controllers` | `HomeViewController` (`ScreenNamed` `home`, hosts the tabs), `ProductViewController` (`product_detail`), `SettingsViewController` (class name), `LegacyLink` (plain) |
| `RubiconDemo/UI` | SwiftUI: theme, components, the five tabs and Settings |
| `fake-server/server.py` | The Android demo's standard-library Python backend, with the iOS names |
| `docs/manual-checklist.md` | The scenarios run before every release, with the last result |

Bundle id `com.rubicon.demo`; URL scheme `rubicon`. Swift 5 language mode, iOS 16 and later; the SDK
comes from `../rubicon-ios-sdk` as a path dependency until a release is tagged.

## Commands

```bash
brew install xcodegen                      # once
xcodegen generate                          # after every change to project.yml
python3 fake-server/server.py              # the simulator reaches it at http://127.0.0.1:8080
xcodebuild -project RubiconDemo.xcodeproj -scheme RubiconDemo \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath .build/derived build
xcrun simctl install booted .build/derived/Build/Products/Debug-iphonesimulator/RubiconDemo.app
xcrun simctl launch booted com.rubicon.demo
xcrun simctl openurl booted "rubicon://open/promo?utm_source=terminal"
xcrun simctl terminate booted com.rubicon.demo
log stream --predicate 'subsystem == "com.rubicon.analytics"' --level debug   # the SDK's sink
```

Or open `RubiconDemo.xcodeproj` in Xcode and run.

## Rules

- The app is a test harness: every button triggers one SDK behaviour and says what to expect; the
  wording comes from the decision pages. No analytics of its own, no third-party dependency.
- The SDK is created once, at launch, from the saved settings; a setting changes at the next launch.
  The app never restarts itself apart from `exit(0)` on "Save and quit", which is for the demo only.
- `debug` is off by default here: with it on, a developer's mistake traps the process (iOS
  Configuration 2), and the SDK offers no hook to turn that into a message.
- The scene lifecycle is mandatory (iOS 27 SDK); the screens the SDK names are view controllers
  because `UIHostingController` never produces a screen view (iOS Lifecycle 2).
- The app's own HTTP calls use `localhost`, the SDK uses `127.0.0.1`: the observer never captures
  the SDK's own host, so the fake backend needs a second name.
