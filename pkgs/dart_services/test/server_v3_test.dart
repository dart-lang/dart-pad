// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_services/server.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:dart_services/src/shared/services.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('server v3', () {
    late final Sdk sdk;
    late final EndpointsServer server;
    late final Client httpClient;
    late final ServicesClient client;

    setUpAll(() async {
      final channel = Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel;

      sdk = Sdk.create(channel);
      server = await EndpointsServer.serve(0, sdk, null);

      httpClient = Client();
      client = ServicesClient(
        httpClient,
        rootUrl: 'http://localhost:${server.port}/',
      );
    });

    tearDownAll(() async {
      client.dispose();
      await server.close();
    });

    test('version', () async {
      final result = await client.version();
      expect(result.dartVersion, startsWith('3.'));
      expect(result.flutterVersion, startsWith('3.'));
      expect(result.packages, isNotEmpty);
    });

    test('analyze', () async {
      final result = await client.analyze(SourceRequest(source: '''
void main() {
  print('hello world');
}
'''));
      expect(result.issues, isEmpty);
    });

    test('analyze flutter', () async {
      final result = await client.analyze(SourceRequest(source: '''
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello world'),
        ),
      ),
    );
  }
}
'''));

      expect(result, isNotNull);
      expect(result.issues, isEmpty);
    });

    test('analyze errors', () async {
      final result = await client.analyze(SourceRequest(source: r'''
void main() {
  int foo = 'bar';
  print('hello world: $foo');
}
'''));

      expect(result.issues, hasLength(1));

      final issue = result.issues.first;
      expect(issue.kind, 'error');
      expect(
          issue.message,
          contains(
              "A value of type 'String' can't be assigned to a variable of type 'int'"));
      expect(issue.line, 2);
    });

    test('complete', () async {
      final result = await client.complete(SourceRequest(source: '''
void main() {
  print('hello world');
}
''', offset: 18));

      expect(result.replacementOffset, 16);
      expect(result.replacementLength, 5);
      expect(result.suggestions, isNotEmpty);

      final suggestions = result.suggestions;
      final suggestion = suggestions.firstWhereOrNull((s) {
        return s.kind == 'INVOCATION' && s.completion == 'print';
      });
      expect(suggestion, isNotNull);
      expect(suggestion!.returnType, 'void');
      expect(suggestion.elementKind, 'FUNCTION');
    });

    test('format', () async {
      final result = await client.format(SourceRequest(source: '''
void main() { print('hello world'); }
'''));

      expect(result.source, '''
void main() {
  print('hello world');
}
''');
    });

    test('format no changes', () async {
      final result = await client.format(SourceRequest(source: '''
void main() {
  print('hello world');
}
'''));

      expect(result.source, '''
void main() {
  print('hello world');
}
''');
    });

    test('format preserves offset', () async {
      final result = await client.format(SourceRequest(
        source: '''
void main() { print('hello world'); }
''',
        offset: 15,
      ));

      expect(result.source, '''
void main() {
  print('hello world');
}
''');
      expect(result.offset, 17);
    });

    test('compile', () async {
      final result = await client.compile(CompileRequest(source: '''
void main() {
  print('hello world');
}
'''));
      expect(result.result, isNotEmpty);
      expect(result.result.length, greaterThanOrEqualTo(10 * 1024));
    });

    test('compile with error', () async {
      try {
        await client.compile(CompileRequest(source: '''
void main() {
  print('hello world')
}
'''));
        fail('compile error expected');
      } on ApiRequestError catch (e) {
        expect(e.body, contains("Expected ';' after this."));
      }
    });
  });
}
