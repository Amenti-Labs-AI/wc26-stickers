# Development — WC26 Album Tracker

Build, test, and deploy the Flutter app. For product overview and CV pipeline summary, see [README](../README.md).

## Quick start

```bash
make              # list all targets
make get          # flutter pub get
make scan-check   # host OCR pipeline tests (~15s) — run before deploy
```

**Physical device (camera + ML Kit OCR):**

```bash
make device           # iPhone via USB
make android-device   # Android via USB (Pixel 4a / stock Android)
make scan-check-device   # 21 integration tests on USB Android/iOS
```

## Dev commands

| Target | Purpose |
|--------|---------|
| `make get` | `flutter pub get` |
| `make test` | All unit tests |
| `make analyze` | `flutter analyze` |
| `make ci` | analyze + test |
| `make scan-check` | Scan pipeline host tests (no device) |
| `make scan-check-device` | Portrait OCR on physical Android/iOS |
| `make scan-check-device-mex` | MEX-only device OCR loop |
| `make ios` | iOS Simulator (collection UI; no camera) |
| `make device` | Physical iPhone — live camera scan |
| `make android` | Android device or emulator |
| `make android-device` | Physical Android only (USB) |
| `make android-devices` | List `adb` + `flutter devices` |
| `make android-screenshot NAME=home` | Capture Android screen → `docs/screenshots/` |
| `make ios-screenshot NAME=home` | Capture iOS screen → `docs/screenshots/` |
| `make android-apk` | Build debug APK |
| `make android-apk-release` | Build release APK |
| `make android-install` | Debug APK + `adb install` |
| `make android-install-release` | Release APK + install |
| `make release` | Test + release APK (+ IPA on macOS) |
| `make generate-catalog` | Regenerate `assets/catalog/wc26_catalog.json` |
| `make generate-templates` | Regenerate `assets/page_templates/` |

**Manual Flutter / Xcode:** `source ios/scripts/env.sh` then `flutter devices`.

## Requirements

- Flutter **3.5+** (stable)
- iOS: Xcode 15+, physical iPhone for camera scan
- Android: API 21+

## First-time setup

```bash
flutter pub get
# iOS (once, needs password):
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Connect iPhone via USB, unlock, trust this Mac, then `make device`.

**Android (Pixel 4a / stock Android):** [pixel4a-android-testing.md](android/pixel4a-android-testing.md) — `make android-device`, `make android-install`

## Scan pipeline

Live Scan uses portrait-label OCR (`PortraitOcrScanner`). Details, test matrix, and fixture paths: [ml/strategy.md](ml/strategy.md).

Pre-deploy gate:

```bash
make scan-check          # host (~15s)
make scan-check-device   # USB device (optional, when OCR behavior changed)
```

## README screenshots

The app does not write screenshots to disk. Capture the **current screen** from a connected device:

**Android (USB):**

```bash
# Open Home tab, then:
make android-screenshot NAME=home
# Open Scan tab with overlays visible:
make android-screenshot NAME=scan
# Open Collection tab:
make android-screenshot NAME=collection
```

**iOS (Simulator or USB iPhone):**

```bash
make ios-screenshot NAME=home
make ios-screenshot NAME=scan
make ios-screenshot NAME=collection
```

Files land in [`docs/screenshots/`](../docs/screenshots/) and render in [README](../README.md).

Manual Android one-liner: `adb exec-out screencap -p > docs/screenshots/home.png`

## Project layout

**Deployable** (ships to users): `lib/`, `assets/`, and each platform’s `{platform}/src/` (native shell + platform assets).

**Dev-only:** `tooling/`, `build/`, `{platform}/scripts/`, `test/`, `integration_test/`, `docs/`.

| Path | Role |
|------|------|
| `lib/` | Dart app |
| `assets/catalog/` | 992-sticker JSON catalog |
| `assets/page_templates/` | Per-team slot codes and layout metadata |
| `assets/test_fixtures/` | OCR integration test photos |
| `ios/src/` | iOS native app — [ios/README.md](../ios/README.md) |
| `android/src/` | Android app module — [android/README.md](../android/README.md) |
| `macos/src/` | macOS shell (optional; no camera scan) |
| `tooling/` | Catalog/template generators |

Platform roots (`ios/Runner`, `android/app`, …) are **symlinks** into `src/` for Flutter CLI. Edit deployable sources under `src/`.

## CI

GitHub Actions: analyze + test on Ubuntu (`.github/workflows/ci.yml`).

## License

[MIT](../LICENSE) — Copyright © 2026 [Amenti Labs, LLC](https://amentilabs.dev/)
