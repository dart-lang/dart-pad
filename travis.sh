#!/bin/bash

# Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

echo "Testing dart-services"

cd dart-services

./tool/travis.sh

echo "Testing finished!"
