#!/bin/bash

# Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Run pub get to fetch packages.
pub get

# Prepare to run unit tests (but do not actually run tests).
pub run grinder buildbot

# Gather coverage and upload to Coveralls.
if [ "$REPO_TOKEN" ] && [ "$TRAVIS_DART_VERSION" = "dev" ]; then
  OBS_PORT=9292
  echo "Collecting coverage on port $OBS_PORT..."

  # Start tests in one VM.
  dart \
    --enable-vm-service=$OBS_PORT \
    --pause-isolates-on-exit \
    test/all.dart &

  # Run the coverage collector to generate the JSON coverage report.
  pub run coverage:collect_coverage \
    --port=$OBS_PORT \
    --out=coverage.json \
    --wait-paused \
    --resume-isolates

  echo "Generating LCOV report..."
  pub run coverage:format_coverage \
    --lcov \
    --in=coverage.json \
    --out=lcov.info \
    --packages=.packages \
    --report-on=lib

  coveralls-lcov --repo-token="${REPO_TOKEN}" lcov.info
else
  dart test/all.dart
fi
