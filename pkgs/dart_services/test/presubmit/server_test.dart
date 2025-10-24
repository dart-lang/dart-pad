// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/server.dart';
import 'package:test/test.dart';

import '../probes_and_presubmit/server_testing.dart';

void main() async {
  final runner = TestServerRunner();
  await runner.maybeStart();

  group('server', () {
    // Test regular backend.
    testServer(runner.client);

    // Test websocket backend.
    testServerWebsocket(runner.websocketClient);
  });
}
