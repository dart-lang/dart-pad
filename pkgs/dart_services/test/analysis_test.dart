// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/analysis.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:dartpad_shared/model.dart' as api;
import 'package:test/test.dart';

import 'src/sample_code.dart';

void main() => defineTests();

void defineTests() {
  group('analysis', () {
    final sdk = Sdk.fromLocalFlutter();
    late AnalysisServerWrapper analysisServer;

    setUpAll(() async {
      analysisServer = AnalysisServerWrapper(sdkPath: sdk.dartSdkPath);
      await analysisServer.init();
    });

    tearDownAll(() => analysisServer.shutdown());

    test('simple_completion', () async {
      // Just after `i.` on line 3 of [completionCode]
      final results = await analysisServer.complete(completionCode, 32);
      expect(results.replacementLength, 0);
      expect(results.replacementOffset, 32);
      final completions = results.suggestions.map((c) => c.completion).toList();
      expect(completions, contains('abs'));
      expect(completionsContains(results, 'codeUnitAt'), false);
    });

    // https://github.com/dart-lang/dart-pad/issues/2005
    test('Trigger lint with Dart code', () async {
      final results = await analysisServer.analyze(lintWarningTrigger);
      expect(results.issues.length, 1);
      final issue = results.issues[0];
      expect(issue.location.line, 2);
      expect(issue.location.column, 7);
      expect(issue.kind, 'info');
      expect(issue.message,
          'An uninitialized variable should have an explicit type annotation.');
      expect(issue.code, 'prefer_typing_uninitialized_variables');
    });

    test('completions polluted on second request (repro #126)', () async {
      // https://github.com/dart-lang/dart-services/issues/126
      return analysisServer.complete(completionFilterCode, 17).then((results) {
        return analysisServer
            .complete(completionFilterCode, 17)
            .then((results) {
          expect(results.replacementLength, 2);
          expect(results.replacementOffset, 16);
          expect(completionsContains(results, 'print'), true);
          expect(completionsContains(results, 'pow'), false);
        });
      });
    });

    test('disallow path imports', () async {
      // We're testing here that we don't have any path imports - we don't want
      // to enable browsing the file system.
      final testCode = "import '/'; main() { int a = 0; a. }";
      final results = await analysisServer.complete(testCode, 9);
      final completions = results.suggestions;

      if (completions.isNotEmpty) {
        expect(completions.every((completion) {
          return completion.completion.startsWith('dart:') ||
              completion.completion.startsWith('package:');
        }), true);
      }
    });

    test('Error on VM library imports', () async {
      final results = await analysisServer.analyze(unsupportedCoreLibrary);

      expect(results.issues, hasLength(1));
      final issue = results.issues.first;
      expect(issue.message, contains('Unsupported library on the web'));
    });

    test('Warn on deprecated web library imports', () async {
      final results = await analysisServer.analyze(deprecatedWebLibrary);

      expect(results.issues, hasLength(1));
      final issue = results.issues.first;
      expect(issue.message, contains('Deprecated core web library'));
    });

    test('import_dart_core_test', () async {
      // Ensure we can import dart: imports.
      final testCode = "import 'dart:c'; main() { int a = 0; a. }";

      final results = await analysisServer.complete(testCode, 14);
      final completions = results.suggestions;

      expect(
        completions
            .every((completion) => completion.completion.startsWith('dart:')),
        true,
      );
      expect(
        completions
            .any((completion) => completion.completion.startsWith('dart:')),
        true,
      );
    });

    test('import_and_other_test', () async {
      final testCode = "import '/'; main() { int a = 0; a. }";
      final results = await analysisServer.complete(testCode, 34);

      expect(completionsContains(results, 'abs'), true);
    });

    test('quickFix simple', () async {
      final results = await analysisServer.fixes(quickFixesCode, 25);
      final changes = results.fixes;

      expect(changes, isNotEmpty);

      // "Ignore 'unused_local_variable' for this line"
      expect(changes.map((e) => e.message), contains(startsWith('Ignore ')));

      // "Insert ';'"
      expect(changes.map((e) => e.message), contains(startsWith('Insert ')));
      expect(
          changes.map((e) => e.edits.first.replacement), contains(equals(';')));
    });

    test('format simple', () async {
      final results = await analysisServer.format(badFormatCode, 0);
      expect(results.source, formattedCode);
    });

    test('format good code', () async {
      final results =
          await analysisServer.format(formattedCode.replaceAll('\n', ' '), 0);
      expect(results.source, formattedCode);
    });

    test('format with issues', () async {
      final results = await analysisServer.format(formatWithIssues, 0);
      expect(results.source, formatWithIssues);
    });

    test('analyze', () async {
      final results = await analysisServer.analyze(sampleCode);
      expect(results.issues, isEmpty);
    });

    test('analyze with errors', () async {
      final results = await analysisServer.analyze(sampleCodeError);
      expect(results.issues, hasLength(1));
    });

    test('filter completions', () async {
      // just after A
      final idx = 61;
      expect(completionLargeNamespaces.substring(idx - 1, idx), 'A');
      final results =
          await analysisServer.complete(completionLargeNamespaces, 61);
      expect(completionsContains(results, 'A'), true);
      expect(completionsContains(results, 'AB'), true);
      expect(completionsContains(results, 'ABC'), true);
      expect(completionsContains(results, 'a'), true);
      expect(completionsContains(results, 'ZZ'), false);
    });

    test('analyze working Dart code', () async {
      final results = await analysisServer.analyze(sampleCode);
      expect(results.issues, isEmpty);
    });

    test('analyze working Flutter code', () async {
      final results = await analysisServer.analyze(sampleCodeFlutter);
      expect(results.issues, isEmpty);
    });
  });

  group('analysis flutter', () {
    final sdk = Sdk.fromLocalFlutter();
    late AnalysisServerWrapper analysisServer;

    setUpAll(() async {
      analysisServer = AnalysisServerWrapper(sdkPath: sdk.dartSdkPath);
      await analysisServer.init();
    });

    tearDownAll(() async {
      await analysisServer.shutdown();
    });

    test('analyze counter app', () async {
      final results = await analysisServer.analyze(sampleCodeFlutterCounter);
      expect(results.issues, isEmpty);
    });

    test('analyze Draggable Physics sample', () async {
      final results =
          await analysisServer.analyze(sampleCodeFlutterDraggableCard);
      expect(results.issues, isEmpty);
    });

    test('reports errors with Flutter code', () async {
      final results = await analysisServer.analyze('''
import 'package:flutter/material.dart';

String x = 7;

void main() async {
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false, home: Scaffold(body: HelloWorld())));
}

class HelloWorld extends StatelessWidget {
  @override
  Widget build(context) => const Center(child: Text('Hello world'));
}
''');
      expect(results.issues, hasLength(1));
      final issue = results.issues[0];
      expect(issue.location.line, 3);
      expect(issue.kind, 'error');
      expect(
          issue.message,
          "A value of type 'int' can't be assigned to a variable of type "
          "'String'.");
    });

    // https://github.com/dart-lang/dart-pad/issues/2005
    test('reports lint with Flutter code', () async {
      final results = await analysisServer.analyze('''
import 'package:flutter/material.dart';

void main() async {
  var unknown;
  print(unknown);

  runApp(MaterialApp(
      debugShowCheckedModeBanner: false, home: Scaffold(body: HelloWorld())));
}

class HelloWorld extends StatelessWidget {
  @override
  Widget build(context) => const Center(child: Text('Hello world'));
}
''');
      expect(results.issues, hasLength(1));
      final issue = results.issues[0];
      expect(issue.location.line, 4);
      expect(issue.kind, 'info');
      expect(issue.message,
          'An uninitialized variable should have an explicit type annotation.');
    });

    test('analyze counter app', () async {
      final results = await analysisServer.analyze(sampleCodeFlutterCounter);
      expect(results.issues, isEmpty);
    });

    test('analyze Draggable Physics sample', () async {
      final results =
          await analysisServer.analyze(sampleCodeFlutterDraggableCard);
      expect(results.issues, isEmpty);
    });

    test('analyze counter app', () async {
      final results = await analysisServer.analyze(sampleCodeFlutterCounter);
      expect(results.issues, isEmpty);
    });

    test('analyze Draggable Physics sample', () async {
      final results =
          await analysisServer.analyze(sampleCodeFlutterDraggableCard);
      expect(results.issues, isEmpty);
    });
  });
}

/// Returns whether the completion [response] contains [expected].
bool completionsContains(api.CompleteResponse response, String expected) {
  return response.suggestions
      .any((completion) => completion.completion == expected);
}

const completionCode = r'''
void main() {
  int i = 0;
  i.
}
''';

const completionFilterCode = r'''
void main() {
  pr
}
''';

const completionLargeNamespaces = r'''
class A {}
class AB {}
class ABC {}
void main() {
  var c = A
}
class ZZ {}
class a {}
''';

const quickFixesCode = r'''
void main() {
  int i = 0
}
''';

const badFormatCode = r'''
void main()
{
int i = 0;
}
''';

const formattedCode = r'''
void main() {
  int i = 0;
}
''';

const formatWithIssues = '''
void main() { foo() }
''';

const lintWarningTrigger = '''
void main() async {
  var unknown;
  print(unknown);
}
''';

const unsupportedCoreLibrary = '''
import 'dart:io' as io;

void main() {
  print(io.exitCode);
}
''';

const deprecatedWebLibrary = '''
import 'dart:js' as js;

void main() {
  print(js.context);
}
''';
