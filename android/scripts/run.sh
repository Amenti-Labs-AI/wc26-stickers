#!/usr/bin/env bash
# Run on connected Android device or emulator.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=env.sh
source "$ROOT/android/scripts/env.sh"

flutter pub get
exec flutter run "$@"
