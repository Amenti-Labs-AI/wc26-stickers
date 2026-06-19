#!/usr/bin/env bash
# Source for manual Android/flutter commands from repo root:
#   source android/scripts/env.sh
#
# Adds platform-tools to PATH when ANDROID_HOME or local.properties is set.

_android_env() {
  local root prop sdk
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  prop="$root/android/local.properties"
  if [[ -z "${ANDROID_HOME:-}" && -f "$prop" ]]; then
    sdk="$(grep -E '^sdk\.dir=' "$prop" | cut -d= -f2- | sed 's/\\:/:/g' | sed 's/\\\\/\\/g')"
    if [[ -n "$sdk" && -d "$sdk" ]]; then
      export ANDROID_HOME="$sdk"
    fi
  fi
  if [[ -z "${ANDROID_HOME:-}" && -d "$HOME/Library/Android/sdk" ]]; then
    export ANDROID_HOME="$HOME/Library/Android/sdk"
  fi
  if [[ -z "${JAVA_HOME:-}" && -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  fi
  if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME/platform-tools" ]]; then
    export PATH="$ANDROID_HOME/platform-tools:$PATH"
  fi
  if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]]; then
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
  fi
  if [[ -n "${JAVA_HOME:-}" && -d "$JAVA_HOME/bin" ]]; then
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _android_env
  exec "$@"
else
  _android_env
fi
