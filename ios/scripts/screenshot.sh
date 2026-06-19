#!/usr/bin/env bash
# Capture iOS Simulator or physical iPhone screen → docs/screenshots/<name>.png
#
# Usage:
#   bash ios/scripts/screenshot.sh home
#   make ios-screenshot NAME=scan
#
# Open the app screen you want first, then run this command.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/ios/scripts/env.sh"

NAME="${1:-capture}"
OUT="$ROOT/docs/screenshots/${NAME}.png"
mkdir -p "$ROOT/docs/screenshots"

if xcrun simctl list devices booted 2>/dev/null | grep -q "(Booted)"; then
  xcrun simctl io booted screenshot "$OUT"
  echo "Saved (Simulator) → $OUT"
  exit 0
fi

# Physical device — Xcode devicectl (Xcode 15+)
UDID="$(flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
for d in json.load(sys.stdin):
    if d.get('emulator') is False and 'ios' in (d.get('targetPlatform') or ''):
        print(d['id'])
        break
" 2>/dev/null || true)"

if [[ -z "$UDID" ]]; then
  echo "No booted Simulator or physical iOS device found." >&2
  echo "  Simulator: make ios, then re-run" >&2
  echo "  iPhone: connect USB, trust Mac, make device" >&2
  exit 1
fi

if xcrun devicectl device capture screenshot --device "$UDID" --output "$OUT" 2>/dev/null; then
  echo "Saved (device) → $OUT"
  exit 0
fi

# Fallback: libimobiledevice if installed
if command -v idevicescreenshot >/dev/null; then
  idevicescreenshot -u "$UDID" "$OUT"
  echo "Saved (idevicescreenshot) → $OUT"
  exit 0
fi

echo "Could not capture screenshot. Install Xcode 15+ or: brew install libimobiledevice" >&2
exit 1
