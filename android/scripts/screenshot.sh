#!/usr/bin/env bash
# Capture the current Android screen → docs/screenshots/<name>.png
#
# Usage:
#   bash android/scripts/screenshot.sh home
#   make android-screenshot NAME=scan
#
# Open the app screen you want first, then run this command.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/android/scripts/env.sh"

NAME="${1:-capture}"
OUT="$ROOT/docs/screenshots/${NAME}.png"

DEVICE="$(adb devices 2>/dev/null | awk '/\tdevice$/{print $1; exit}')"
if [[ -z "$DEVICE" ]]; then
  echo "No Android device found (adb devices)." >&2
  exit 1
fi

mkdir -p "$ROOT/docs/screenshots"
adb -s "$DEVICE" exec-out screencap -p > "$OUT"

echo "Saved $OUT ($(du -h "$OUT" | awk '{print $1}'))"
echo "Tip: README expects home.png, scan.png, collection.png"
