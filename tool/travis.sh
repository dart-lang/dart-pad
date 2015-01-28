#!/bin/bash

# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Verify that the libraries are error free.
dartanalyzer --fatal-warnings \
  lib/dartpad.dart \
  test/all.dart \
  web/dartpad.dart

# Run the tests.
dart test/all.dart

# Build the app (into build/web).
dart tool/grind.dart build

# TODO: We need to run the UI/web tests as well.
