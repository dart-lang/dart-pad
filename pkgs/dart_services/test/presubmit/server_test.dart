// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/server.dart';
import 'package:dartpad_shared/services.dart';
import 'package:test/test.dart';

import '../probes_and_presubmit/server_test.dart';
import '../test_infra/sample_code.dart';

void main() {
  group('server', () {
    final runner = TestServerRunner();
    late final DartServicesClient client;

    setUpAll(() async {
      await runner.maybeStart();
      client = runner.client;
    });

    testServer(client);

    void testDDCEndpoint(
      String endpointName,
      Future<CompileDDCResponse> Function(CompileRequest) endpoint, {
      required bool expectDeltaDill,
      Future<String> Function(String source)? generateLastAcceptedDill,
    }) {
      group(endpointName, () {
        test('compile', () async {
          final result = await endpoint(
            CompileRequest(
              source: '''
void main() {
  print('hello world');
}
''',
              deltaDill: await generateLastAcceptedDill?.call(sampleCode),
            ),
          );
          expect(result.result, isNotEmpty);
          expect(result.result.length, greaterThanOrEqualTo(512));
          expect(result.modulesBaseUrl, isNotEmpty);
          expect(result.deltaDill, expectDeltaDill ? isNotEmpty : isNull);
        });

        test('compile flutter', () async {
          final result = await endpoint(
            CompileRequest(
              source: '''
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('hello world')),
      ),
    );
  }
}
''',
              deltaDill: await generateLastAcceptedDill?.call(sampleCode),
            ),
          );
          expect(result.result, isNotEmpty);
          expect(result.result.length, greaterThanOrEqualTo(10 * 1024));
          expect(result.modulesBaseUrl, isNotEmpty);
        });

        test('compile with error', () async {
          try {
            await endpoint(
              CompileRequest(
                source: '''
void main() {
  print('hello world')
}
''',
                deltaDill: await generateLastAcceptedDill?.call(sampleCode),
              ),
            );
            fail('compile error expected');
          } on ApiRequestError catch (e) {
            expect(e.body, contains("Expected ';' after this."));
          }
        });
      });
    }

    testDDCEndpoint(
      'compileDDC',
      (request) => client.compileDDC(request),
      expectDeltaDill: false,
    );
    if (runner.sdk.dartMajorVersion >= 3 && runner.sdk.dartMinorVersion >= 8) {
      testDDCEndpoint(
        'compileNewDDC',
        (request) => client.compileNewDDC(request),
        expectDeltaDill: true,
      );
      testDDCEndpoint(
        'compileNewDDCReload',
        (request) => client.compileNewDDCReload(request),
        expectDeltaDill: true,
        generateLastAcceptedDill:
            (source) async =>
                (await client.compileNewDDC(
                  CompileRequest(source: source),
                )).deltaDill!,
      );
    }
  });
}
