# Android platform

## What ships in the APK/AAB

| Path | Deployable |
|------|------------|
| **`src/`** | Application module — `AndroidManifest.xml`, `MainActivity.kt`, **`src/main/res/`** (icons, launch drawable, themes) |

Shared Dart + global assets live at repo root: `lib/`, `assets/`.

## Dev-only (not in Play Store binary)

| Path | Purpose |
|------|---------|
| **`scripts/`** | `make android`, `make android-device`, APK build/install — see [docs/android/pixel4-grapheneos-testing.md](../docs/android/pixel4-grapheneos-testing.md) |
| **`build.gradle.kts`**, **`settings.gradle.kts`**, **`gradle/`** | Gradle build shell |
| **`gradlew`** | Wrapper |

## Flutter compatibility

`app` is a **symlink** to `src/`. Flutter expects `android/app/`; edit deployable code under **`src/`**.
