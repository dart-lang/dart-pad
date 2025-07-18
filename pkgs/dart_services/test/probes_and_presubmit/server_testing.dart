// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:dartpad_shared/services.dart';
import 'package:test/test.dart';

import 'ddc_testing.dart';

void testServer(DartServicesClient client, {int? retry}) {
  group('server at ${client.rootUrl}', () {
    testDDCEndpoint(
      'compileDDC',
      (request) => client.compileDDC(request),
      expectDeltaDill: false,
    );

    test('version', () async {
      final result = await client.version();
      expect(result.dartVersion, startsWith('3.'));
      expect(result.flutterVersion, startsWith('3.'));
      expect(result.engineVersion, isNotEmpty);
      expect(result.packages, isNotEmpty);
    });

    test('analyze', () async {
      final result = await client.analyze(
        SourceRequest(
          source: '''
void main() {
  print('hello world');
}
''',
        ),
      );
      expect(result.issues, isEmpty);
    });

    test('analyze flutter', () async {
      final result = await client.analyze(
        SourceRequest(
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
        body: Center(
          child: Text('Hello world'),
        ),
      ),
    );
  }
}
''',
        ),
      );

      expect(result, isNotNull);
      expect(result.imports, contains('package:flutter/material.dart'));
      expect(result.issues, isEmpty);
    });

    test('analyze errors', () async {
      final result = await client.analyze(
        SourceRequest(
          source: r'''
void main() {
  int foo = 'bar';
  print('hello world: $foo');
}
''',
        ),
      );

      expect(result.issues, hasLength(1));

      final issue = result.issues.first;
      expect(issue.kind, 'error');
      expect(
        issue.message,
        contains(
          "A value of type 'String' can't be assigned to a variable of type 'int'",
        ),
      );
      expect(issue.location.line, 2);
    });

    test('analyze unsupported import', () async {
      final result = await client.analyze(
        SourceRequest(
          source: r'''
import 'package:foo_bar/foo_bar.dart';

void main() => print('hello world');
''',
        ),
      );

      expect(result.issues, isNotEmpty);

      final issue = result.issues.first;
      expect(issue.kind, 'warning');
      expect(
        issue.message,
        contains("Unsupported package: 'package:foo_bar'."),
      );
      expect(issue.location.line, 1);
    });

    test('analyze firebase import', () async {
      final result = await client.analyze(
        SourceRequest(
          source: r'''
import 'package:firebase_core/firebase_core.dart';

void main() => print('hello world');
''',
        ),
      );

      expect(result.issues, isNotEmpty);

      final issue = result.issues.first;
      expect(issue.kind, 'warning');
      expect(issue.message, contains('Unsupported package:'));
      expect(issue.location.line, 1);
    });

    test('complete', () async {
      final result = await client.complete(
        SourceRequest(
          source: '''
void main() {
  print('hello world');
}
''',
          offset: 18,
        ),
      );

      expect(result.replacementOffset, 16);
      expect(result.replacementLength, 5);
      expect(result.suggestions, isNotEmpty);

      final suggestions = result.suggestions;
      final suggestion = suggestions.firstWhereOrNull((s) {
        return s.kind == 'INVOCATION' && s.completion == 'print';
      });
      expect(suggestion, isNotNull);
      expect(suggestion!.returnType, 'void');
      expect(suggestion.parameterNames, isNotEmpty);
      expect(suggestion.elementKind, 'FUNCTION');
      expect(suggestion.elementParameters, isNotEmpty);
    });

    test('format', () async {
      final result = await client.format(
        SourceRequest(
          source: '''
void main() { print('hello world'); }
''',
        ),
      );

      expect(result.source, '''
void main() {
  print('hello world');
}
''');
    });

    test('format no changes', () async {
      final result = await client.format(
        SourceRequest(
          source: '''
void main() {
  print('hello world');
}
''',
        ),
      );

      expect(result.source, '''
void main() {
  print('hello world');
}
''');
    });

    test('format preserves offset', () async {
      final result = await client.format(
        SourceRequest(
          source: '''
void main() { print('hello world'); }
''',
          offset: 15,
        ),
      );

      expect(result.source, '''
void main() {
  print('hello world');
}
''');
      expect(result.offset, 17);
    });

    test('compile', () async {
      final result = await client.compile(
        CompileRequest(
          source: '''
void main() {
  print('hello world');
}
''',
        ),
      );
      expect(result.result, isNotEmpty);
      expect(result.result.length, greaterThanOrEqualTo(10 * 1024));
    });

    test('compile with error', () async {
      try {
        await client.compile(
          CompileRequest(
            source: '''
void main() {
  print('hello world')
}
''',
          ),
        );
        fail('compile error expected');
      } on ApiRequestError catch (e) {
        expect(e.body, contains("Expected ';' after this."));
      }
    });

    test('document', () async {
      final result = await client.document(
        SourceRequest(
          source: '''
void main() {
  print('hello world');
}
''',
          offset: 18,
        ),
      );

      expect(
        result.dartdoc!.toLowerCase(),
        contains('prints an object to the console'),
      );
      expect(result.containingLibraryName, 'dart:core');
      expect(result.elementDescription, isNotNull);
      expect(result.deprecated, false);
      expect(result.propagatedType, isNull);
      expect(result.elementKind, 'function');
    });

    test('document empty', () async {
      final result = await client.document(
        SourceRequest(
          source: '''
void main() {
  print('hello world');
}
''',
          offset: 15,
        ),
      );

      expect(result.dartdoc, isNull);
      expect(result.elementKind, isNull);
      expect(result.elementDescription, isNull);
    });

    test('fixes', () async {
      final result = await client.fixes(
        SourceRequest(
          source: '''
void main() {
  var foo = 'bar';
  print('hello world');
}
''',
          offset: 21,
        ),
      );

      // Dart 3.5 returns 3 fixes; Dart 3.6 returns 4.
      expect(result.fixes, anyOf(hasLength(3), hasLength(4)));

      final fix = result.fixes.firstWhereOrNull(
        (fix) => fix.message.contains('Ignore'),
      );
      expect(fix, isNotNull);
      expect(fix!.edits, hasLength(1));
      expect(fix.linkedEditGroups, isEmpty);
      expect(
        fix.edits.first.replacement,
        contains('// ignore: unused_local_variable'),
      );
    });

    test('fixes empty', () async {
      final result = await client.fixes(
        SourceRequest(
          source: '''
void main() {
  var foo = 'bar';
  print(foo);
}
''',
          offset: 21,
        ),
      );

      expect(result.fixes, hasLength(0));
    });

    test('assists', () async {
      final result = await client.fixes(
        SourceRequest(
          source: '''
void main() => print('hello world');
''',
          offset: 13,
        ),
      );

      expect(result.fixes, hasLength(0));
      expect(result.assists, isNotEmpty);

      final assist = result.assists.firstWhereOrNull(
        (assist) => assist.message.contains('Convert to block body'),
      );
      expect(assist, isNotNull);
      expect(assist!.edits, hasLength(1));
      expect(assist.linkedEditGroups, isEmpty);
      expect(assist.selectionOffset, greaterThan(0));
      expect(assist.edits.first.replacement, isNotEmpty);
    });
  }, retry: retry);
}
