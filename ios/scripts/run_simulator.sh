#!/usr/bin/env bash
# Run on iOS Simulator (collection UI; Scan → Pick test photo).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/ios/scripts/env.sh"

SIM_NAME="${IOS_SIMULATOR:-iPhone 17 Pro}"

boot_simulator() {
  if xcrun simctl list devices booted 2>/dev/null | grep -q Booted; then
    return 0
  fi
  echo "Booting simulator: $SIM_NAME"
  xcrun simctl boot "$SIM_NAME" 2>/dev/null || true
  open -a Simulator
  for _ in $(seq 1 30); do
    if xcrun simctl list devices booted 2>/dev/null | grep -q Booted; then
      sleep 2
      return 0
    fi
    sleep 1
  done
  echo "Simulator did not boot in time. Open Simulator.app manually, then re-run." >&2
  exit 1
}

resolve_device_id() {
  local id
  id="$(xcrun simctl list devices booted -j 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('state') == 'Booted':
            print(d['udid'])
            raise SystemExit
sys.exit(1)
" 2>/dev/null || true)"
  if [[ -n "$id" ]]; then
    echo "$id"
    return 0
  fi
  echo "$SIM_NAME"
}

boot_simulator
flutter pub get
DEVICE_ID="$(resolve_device_id)"
echo "Running on: $DEVICE_ID"
exec flutter run -d "$DEVICE_ID" "$@"
