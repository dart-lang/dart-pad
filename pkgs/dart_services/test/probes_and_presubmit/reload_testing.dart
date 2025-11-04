// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/services.dart';

import 'ddc_testing.dart';

void testReload(DartPadService client) {
  testDDCEndpoint(
    'compileNewDDC',
    (request) => client.compileNewDDC(request),
    expectDeltaDill: true,
  );
  testDDCEndpoint(
    'compileNewDDCReload',
    (request) => client.compileNewDDCReload(request),
    expectDeltaDill: true,
    generateLastAcceptedDill: (source) async =>
        (await client.compileNewDDC(CompileRequest(source: source))).deltaDill!,
  );
}
