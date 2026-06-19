#!/usr/bin/env bash
# List connected Android devices (adb + flutter).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/android/scripts/env.sh"

echo "=== adb devices ==="
adb devices
if ! adb devices | grep -v '^List' | grep -E 'device$' -q; then
  if system_profiler SPUSBDataType 2>/dev/null | grep -qi 'pixel\|google.*android'; then
    echo ""
    echo "USB shows a Google/Pixel device but adb does not — enable USB debugging on the phone"
    echo "and accept the RSA prompt. See docs/android/pixel4-grapheneos-testing.md#troubleshooting"
  fi
fi
echo ""
echo "=== flutter devices ==="
flutter devices
