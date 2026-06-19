#!/usr/bin/env bash
# Build and install APK on connected device via adb (-r = replace existing).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/android/scripts/env.sh"

BUILD="${BUILD:-debug}"
"$ROOT/android/scripts/build_apk.sh"

case "$BUILD" in
  release) APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk" ;;
  debug)   APK="$ROOT/build/app/outputs/flutter-apk/app-debug.apk" ;;
esac

if ! adb devices | grep -v '^List' | grep -E 'device$' -q; then
  echo "No adb device connected." >&2
  exit 1
fi

echo "Installing $APK ..."
adb install -r "$APK"
echo "Done. Open WC26 Album Tracker on the phone."
