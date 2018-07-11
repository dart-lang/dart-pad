#!/bin/bash

set -e -o pipefail

sh -e /etc/init.d/xvfb start

case $( uname -s ) in
  Linux)
    DART_SDK_ZIP=dartsdk-linux-x64-release.zip
    DARTIUM_ZIP=dartium-linux-x64-release.zip
    ;;
  Darwin)
    DART_SDK_ZIP=dartsdk-macos-x64-release.zip
    DARTIUM_ZIP=dartium-macos-ia32-release.zip
    ;;
esac

CHANNEL=`echo $JOB | cut -f 2 -d -`
echo Fetch Dart channel: $CHANNEL

echo http://storage.googleapis.com/dart-archive/channels/$CHANNEL/release/latest/sdk/$DART_SDK_ZIP
curl -L http://storage.googleapis.com/dart-archive/channels/$CHANNEL/release/latest/sdk/$DART_SDK_ZIP > $DART_SDK_ZIP
echo Fetched new dart version $(unzip -p $DART_SDK_ZIP dart-sdk/version)
rm -rf dart-sdk
unzip $DART_SDK_ZIP > /dev/null

echo http://storage.googleapis.com/dart-archive/channels/$CHANNEL/raw/latest/dartium/$DARTIUM_ZIP
curl -L http://storage.googleapis.com/dart-archive/channels/$CHANNEL/release/latest/dartium/$DARTIUM_ZIP > dartium.zip
unzip dartium.zip > /dev/null
rm -rf dartium
rm dartium.zip
mv dartium-* chromium

echo =============================================================================
. ./scripts/env.sh
$DART --version
$PUB install
