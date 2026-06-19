# iOS platform

## What ships in the app bundle

| Path | Deployable |
|------|------------|
| **`src/Runner/`** | Native app target — `AppDelegate`, `Info.plist`, storyboards, **`Assets.xcassets`** (icons, launch) |
| **`src/RunnerTests/`** | Unit test bundle (TestFlight/App Store: tests not shipped) |
| **`Flutter/`** | Flutter engine glue (xcconfig + generated ephemeral files) |

Shared Dart + global assets live at repo root: `lib/`, `assets/`.

## Dev-only (not in App Store binary)

| Path | Purpose |
|------|---------|
| **`scripts/`** | Simulator/device run helpers (`make ios`, `make device`) |
| **`Podfile`**, **`Pods/`** | CocoaPods dependency resolution |
| **`Runner.xcodeproj`**, **`Runner.xcworkspace`** | Xcode project shell |

## Flutter compatibility

`Runner` and `RunnerTests` at this directory root are **symlinks** into `src/`. Flutter CLI and Xcode expect `ios/Runner/Info.plist`; edit sources under **`src/`**.
