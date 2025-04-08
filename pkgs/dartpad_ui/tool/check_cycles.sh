#!/bin/bash

# Copyright 2025 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


# Fast fail the script on failures.
set -ex

# The directory that this script is located in.
TOOL_DIR=`dirname "$0"`

dart pub global activate layerlens
layerlens --path $TOOL_DIR/.. --fail-on-cycles
