#!/usr/bin/env bash
# Build APK (debug by default; BUILD=release for release).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/android/scripts/env.sh"

BUILD="${BUILD:-debug}"
flutter pub get

case "$BUILD" in
  release)
    echo "Building release APK..."
    flutter build apk --release
    APK="build/app/outputs/flutter-apk/app-release.apk"
    ;;
  debug)
    echo "Building debug APK..."
    flutter build apk --debug
    APK="build/app/outputs/flutter-apk/app-debug.apk"
    ;;
  *)
    echo "Unknown BUILD=$BUILD (use debug or release)" >&2
    exit 1
    ;;
esac

echo ""
echo "APK: $ROOT/$APK"
ls -lh "$APK"
