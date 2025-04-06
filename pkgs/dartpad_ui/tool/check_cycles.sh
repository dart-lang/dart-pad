#!/bin/bash

# Copyright 2023 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Runs `analyze` for all code in the repo.

# Fast fail the script on failures.
set -ex

# The directory that this script is located in.
TOOL_DIR=`dirname "$0"`

cd $TOOL_DIR/..
dart pub global activate layerlens
layerlens --path . --fail-on-cycles
cd -
