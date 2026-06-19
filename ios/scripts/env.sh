# Source when running flutter/xcrun manually from repo root:
#   source ios/scripts/env.sh
#
# Prefer: make ios | make device

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "ios/scripts/env.sh: Xcode not found at $DEVELOPER_DIR" >&2
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer" >&2
  return 1 2>/dev/null || exit 1
fi
