#!/usr/bin/env bash
# Run on a connected physical iPhone/iPad (USB or wireless debugging).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/ios/scripts/env.sh"

flutter pub get

echo "Looking for a connected iOS device..."
if ! flutter devices 2>/dev/null | grep -q '(mobile)'; then
  echo "" >&2
  echo "No iPhone/iPad found. Check:" >&2
  echo "  • USB cable, unlocked phone, 'Trust This Computer'" >&2
  echo "  • Xcode → Window → Devices and Simulators shows the device" >&2
  echo "  • For wireless: enable in Devices and Simulators, same Wi‑Fi" >&2
  echo "" >&2
  echo "Tip: make device — or source ios/scripts/env.sh for manual flutter." >&2
  exit 1
fi

exec flutter run "$@"
