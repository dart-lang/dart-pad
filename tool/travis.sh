#!/bin/bash

# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Install the bower and vulcanize.
npm install -g bower
npm install -g vulcanize

# TODO: use tuneup
# Verify that the libraries are error free.
dartanalyzer --fatal-warnings \
  lib/dart_pad.dart \
  test/all.dart \
  web/main.dart

# Run the command-line tests.
dart test/all.dart

# Build the app and the tests (into build/web and build/test, respectively).
dart tool/grind.dart bower build

# Run the UI/web tests as well.
pub run grinder:test build/test/web.html
