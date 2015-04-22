#!/bin/bash

# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Install the bower and vulcanize.
npm install -g bower
npm install -g vulcanize

# Run the analyze/test/build script.
dart tool/grind.dart buildbot

# Run the UI/web tests as well.
# TODO: Our bot is flakey...
#dart tool/grind.dart test-web

# Run the webdriver integration tests.
dart test/web_integration.dart
