#!/usr/bin/env bash
# Push data/device/panini_wc26.db → connected debug Android device (overwrites device DB).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/android/scripts/env.sh"

PKG="com.amentilabs.panini_wc26_tracker"
DB="databases/panini_wc26.db"
SRC="$ROOT/data/device/panini_wc26.db"

if [[ ! -f "$SRC" ]]; then
  echo "No local DB at $SRC — run make android-pull-db first or copy a file there." >&2
  exit 1
fi

DEVICE="$(adb devices 2>/dev/null | awk '/\tdevice$/{print $1; exit}')"
if [[ -z "$DEVICE" ]]; then
  echo "No Android device found (adb devices)." >&2
  exit 1
fi

echo "Stopping app on $DEVICE…"
adb -s "$DEVICE" shell am force-stop "$PKG" 2>/dev/null || true

echo "Pushing $SRC → device $DB…"
adb -s "$DEVICE" shell run-as "$PKG" mkdir -p databases 2>/dev/null || true
if ! cat "$SRC" | adb -s "$DEVICE" shell run-as "$PKG" tee "$DB" > /dev/null; then
  echo "Failed to push $DB (debug build required for run-as)." >&2
  exit 1
fi

echo "Pushed local DB to device ($(du -h "$SRC" | awk '{print $1}'))"
if command -v sqlite3 >/dev/null; then
  sqlite3 "$SRC" "
    SELECT 'catalog', count(*) FROM catalog
    UNION ALL SELECT 'owned', count(*) FROM collection WHERE owned_count > 0
    UNION ALL SELECT 'missing_scanned', count(*) FROM scanned_missing;
  " | while IFS='|' read -r label count; do
    echo "  $label: $count"
  done
fi
