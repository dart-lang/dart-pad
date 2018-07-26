#!/bin/bash
#
# Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

DBG_OPTION=
# Only enable Dart debugger if DBG_ENABLE is set.
if [ -n "$DBG_ENABLE" ] && [ "$GAE_PARTITION" = "dev" ]; then
  echo "Enabling Dart debugger"
  DBG_OPTION="--debug:${DBG_PORT:-5858}/0.0.0.0"
  echo "Starting Dart with additional options $DBG_OPTION"
fi

if [ -n "$DART_VM_OPTIONS" ]; then
  echo "Starting Dart with additional options $DART_VM_OPTIONS"
fi

exec /usr/bin/dart \
     ${DBG_OPTION} \
     --enable-vm-service:8181/0.0.0.0 \
     ${DART_VM_OPTIONS} \
     bin/server.dart
