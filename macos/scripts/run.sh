#!/usr/bin/env bash
# Run on macOS desktop (optional target; not in default Makefile).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
flutter pub get
exec flutter run -d macos "$@"
