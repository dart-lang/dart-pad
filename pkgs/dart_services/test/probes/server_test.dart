// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Timeout for one test.
@Timeout(Duration(seconds: 180))
library;

import 'package:test/test.dart';

import '../probes_and_presubmit/server_testing.dart';
import '../test_infra/utils.dart';

void main() async {
  group('server', () {
    for (final client in dartServicesProdProbingClients) {
      testServer(client, retry: 3);
    }
  });
}
