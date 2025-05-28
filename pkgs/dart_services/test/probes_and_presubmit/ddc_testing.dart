// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/services.dart';
import 'package:test/test.dart';

import '../test_infra/sample_code.dart';

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
