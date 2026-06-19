#!/usr/bin/env bash
# Pull panini_wc26.db from a connected debug Android device → data/device/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/android/scripts/env.sh"

PKG="com.amentilabs.panini_wc26_tracker"
DB="databases/panini_wc26.db"
OUT="$ROOT/data/device/panini_wc26.db"

DEVICE="$(adb devices 2>/dev/null | awk '/\tdevice$/{print $1; exit}')"
if [[ -z "$DEVICE" ]]; then
  echo "No Android device found (adb devices)." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
if ! adb -s "$DEVICE" exec-out run-as "$PKG" cat "$DB" > "$OUT"; then
  echo "Failed to pull $DB (debug build required for run-as)." >&2
  exit 1
fi

echo "Pulled device DB → $OUT ($(du -h "$OUT" | awk '{print $1}'))"
if command -v sqlite3 >/dev/null; then
  sqlite3 "$OUT" "
    SELECT 'owned', count(*) FROM collection WHERE owned_count > 0
    UNION ALL SELECT 'missing_scanned', count(*) FROM scanned_missing;
  " | while IFS='|' read -r label count; do
    echo "  $label: $count"
  done
fi
