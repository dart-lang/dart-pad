#!/bin/bash
set -e -o pipefail

PLATFORM="$(uname -s)"

# Try to find the SDK alongside the dart command first.
if [[ -z "$DART_SDK" ]]; then
DART=$(which dart) || true
if [[ -x "$DART" ]]; then
  DART_SDK="${DART/dart-sdk\/*/dart-sdk}"
  if [[ ! -e "$DART_SDK" ]]; then
    unset DART DART_SDK
  fi
fi
fi
# Fallback: Assume it's alongside the current directory (e.g. Travis).
if [[ -z "$DART_SDK" ]]; then
DART_SDK="$(pwd)/dart-sdk"
fi

: "${DART:=$DART_SDK/bin/dart}"

if [[ ! -x "$DART" ]]; then
echo Unable to locate the dart binary / SDK. Exiting >&2
exit 3
fi

DARTIUMROOT="$DART_SDK/../chromium"
if [[ -e $DARTIUMROOT ]]; then
  case "$PLATFORM" in
    (Linux) export DARTIUM="$DARTIUMROOT/chrome" ;;
    (Darwin) export DARTIUM="$DARTIUMROOT/Chromium.app/Contents/MacOS/Chromium" ;;
    (*) echo Unsupported platform $PLATFORM.  Exiting ... >&2 ; exit 3 ;;
  esac
fi

export DART_SDK
export DART
export PUB=${PUB:-"$DART_SDK/bin/pub"}
export DARTANALYZER=${DARTANALYZER:-"$DART_SDK/bin/dartanalyzer"}
export DARTIUM_BIN=${DARTIUM_BIN:-"$DARTIUM"}
export PATH=$PATH:$DART_SDK/bin

echo '*********'
echo '** ENV **'
echo '*********'
echo DART_SDK=$DART_SDK
echo DART=$DART
echo PUB=$PUB
echo DARTANALYZER=$DARTANALYZER
echo DARTIUM_BIN=$DARTIUM_BIN
echo PATH=$PATH
$DART --version 2>&1