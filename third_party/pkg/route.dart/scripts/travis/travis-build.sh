#!/bin/bash

set -e -o pipefail

. ./scripts/env.sh

dart -c test/url_template_test.dart
dart -c test/url_pattern_test.dart

export SAUCE_ACCESS_KEY=`echo $SAUCE_ACCESS_KEY | rev`

node "node_modules/karma/bin/karma" start karma.conf \
  --reporters=junit,dots --port=8765 --runner-port=8766 \
  --browsers=Dartium,SL_Chrome,SL_Firefox --single-run --no-colors

