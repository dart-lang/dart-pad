// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/server.dart';
import 'package:test/test.dart';

import '../probes_and_presubmit/reload_testing.dart';
import '../probes_and_presubmit/server_testing.dart';

void main() async {
  final runner = TestServerRunner();
  await runner.maybeStart();

  group('server', () {
    testServer(runner.client);

    if (runner.sdk.dartMajorVersion >= 3 && runner.sdk.dartMinorVersion >= 8) {
      testReload(runner.client);
    }

    testServerWebsocket(runner.websocketClient);
  });
}
