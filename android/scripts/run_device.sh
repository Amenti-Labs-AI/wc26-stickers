#!/usr/bin/env bash
# Run debug build on a connected physical Android device (USB / wireless adb).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/android/scripts/env.sh"

if ! make scan-check; then
  echo "" >&2
  echo "scan-check failed — fix scan tests before deploying to device." >&2
  echo "  make scan-check   re-run locally (~15s)" >&2
  exit 1
fi

flutter pub get

DEVICE="$(adb devices 2>/dev/null | awk '/\tdevice$/{print $1; exit}')"
if [[ -z "$DEVICE" ]]; then
  echo "" >&2
  echo "No Android device found. Check:" >&2
  echo "  • USB cable, unlocked phone, USB debugging enabled" >&2
  echo "  • Stock Android: Settings → System → Developer options → USB debugging" >&2
  echo "  • Accept the RSA fingerprint prompt on the phone" >&2
  echo "  • adb devices  (should show 'device', not 'unauthorized')" >&2
  echo "" >&2
  echo "See docs/android/pixel4a-android-testing.md" >&2
  exit 1
fi

echo "Running on device: $DEVICE"

# Suppress noisy ML Kit / Firebase transport debug spam during flutter run.
adb -s "$DEVICE" shell setprop log.tag.PipelineManager ERROR 2>/dev/null || true
adb -s "$DEVICE" shell setprop log.tag.TransportRuntime ERROR 2>/dev/null || true

GIT_SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)"
echo ""
echo "=== Deploy WC26 Album Tracker @ ${GIT_SHA} ==="
echo "    Live scan: portrait OCR (see docs/ml/strategy.md)"
echo "    Press R in this terminal for full restart after code changes"
echo ""

exec flutter run -d "$DEVICE" --dart-define=BUILD_SHA="$GIT_SHA" "$@"
