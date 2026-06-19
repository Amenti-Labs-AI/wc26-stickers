# macOS platform

## What ships in the .app bundle

| Path | Deployable |
|------|------------|
| **`src/Runner/`** | Native app — `AppDelegate`, `MainFlutterWindow`, entitlements, **`Assets.xcassets`** |
| **`src/RunnerTests/`** | Unit tests (not shipped in release .app) |
| **`Flutter/`** | Flutter engine glue |

Shared Dart + global assets: `lib/`, `assets/` at repo root.

## Dev-only

| Path | Purpose |
|------|---------|
| **`scripts/`** | Reserved for macOS-specific dev helpers |
| **`Podfile`**, **`Runner.xcodeproj`** | Build integration |

`Runner` / `RunnerTests` symlinks at this level point into **`src/`** for Flutter CLI compatibility.
