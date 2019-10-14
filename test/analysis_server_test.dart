// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer_server_test;

import 'package:dart_services/src/analysis_server.dart';
import 'package:dart_services/src/api_classes.dart';
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/flutter_web.dart';
import 'package:test/test.dart';

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

void main() => defineTests();

void defineTests() {
  AnalysisServerWrapper analysisServer;
  FlutterWebManager flutterWebManager;

  group('analysis_server', () {
    setUp(() async {
      flutterWebManager = FlutterWebManager(sdkPath);
      analysisServer = AnalysisServerWrapper(sdkPath, flutterWebManager);
      await analysisServer.init();
    });

    tearDown(() => analysisServer.shutdown());

    test('simple_completion', () {
      // Just after i.
      return analysisServer
          .complete(completionCode, 32)
          .then((CompleteResponse results) {
        expect(results.replacementLength, 0);
        expect(results.replacementOffset, 32);
        expect(completionsContains(results, 'abs'), true);
        expect(completionsContains(results, 'codeUnitAt'), false);
      });
    });

    test('repro #126 - completions polluted on second request', () {
      // https://github.com/dart-lang/dart-services/issues/126
      return analysisServer
          .complete(completionFilterCode, 17)
          .then((CompleteResponse results) {
        return analysisServer
            .complete(completionFilterCode, 17)
            .then((CompleteResponse results) {
          expect(results.replacementLength, 2);
          expect(results.replacementOffset, 16);
          expect(completionsContains(results, 'print'), true);
          expect(completionsContains(results, 'pow'), false);
        });
      });
    });

    test('import_test', () {
      String testCode = "import '/'; main() { int a = 0; a. }";

      return analysisServer
          .complete(testCode, 9)
          .then((CompleteResponse results) {
        expect(results.completions.every((Map<String, String> completion) {
          return completion['completion'].startsWith('dart:');
        }), true);
      });
    });

    test('import_and_other_test', () {
      String testCode = "import '/'; main() { int a = 0; a. }";

      return analysisServer
          .complete(testCode, 34)
          .then((CompleteResponse results) {
        expect(completionsContains(results, 'abs'), true);
      });
    });

    test('simple_quickFix', () {
      return analysisServer
          .getFixes(quickFixesCode, 25)
          .then((FixesResponse results) {
        // Under 2.5 we see 1 fix, under 2.6.dev we are seeing 2.
        expect(results.fixes.length, anyOf(1, 2));
        expect(results.fixes.last.offset, 24);
        expect(results.fixes.last.length, 1); //we need an insertion

        // We should be getting an insert ; fix
        expect(results.fixes.last.fixes.length, 1);
        CandidateFix fix = results.fixes.last.fixes[0];
        expect(fix.message.contains(';'), true);
        expect(fix.edits[0].length, 0);
        expect(fix.edits[0].offset, 25);
        expect(fix.edits[0].replacement, ';');
      });
    });

    test('simple_format', () async {
      FormatResponse results = await analysisServer.format(badFormatCode, 0);
      expect(results.newString, formattedCode);
    });

    test('format good code', () async {
      FormatResponse results =
          await analysisServer.format(formattedCode.replaceAll('\n', ' '), 0);
      expect(results.newString, formattedCode);
    });

    test('format with issues', () async {
      FormatResponse results = await analysisServer.format(formatWithIssues, 0);
      expect(results.newString, formatWithIssues);
    });

    test('analyze', () async {
      AnalysisResults results = await analysisServer.analyze(sampleCode);
      expect(results.issues, isEmpty);
    });

    test('analyze with errors', () async {
      AnalysisResults results = await analysisServer.analyze(sampleCodeError);
      expect(results.issues, hasLength(1));
    });

    test('analyze strong', () async {
      AnalysisResults results = await analysisServer.analyze(sampleStrongError);
      expect(results.issues, hasLength(1));
      AnalysisIssue issue = results.issues.first;
      expect(issue.kind, 'error');
    });

    test('analyze dart-2', () async {
      await analysisServer.shutdown();

      flutterWebManager = FlutterWebManager(sdkPath);

      analysisServer = AnalysisServerWrapper(sdkPath, flutterWebManager);
      await analysisServer.init();

      AnalysisResults results = await analysisServer.analyze(sampleDart2OK);
      expect(results.issues, hasLength(0));
    });

    test('filter completions', () async {
      // just after A
      var idx = 61;
      expect(completionLargeNamespaces.substring(idx - 1, idx), 'A');
      var results =
          await analysisServer.complete(completionLargeNamespaces, 61);
      expect(completionsContains(results, 'A'), true);
      expect(completionsContains(results, 'AB'), true);
      expect(completionsContains(results, 'ABC'), true);
      expect(completionsContains(results, 'a'), true);
      expect(completionsContains(results, 'ZZ'), false);
    });
  });
}

bool completionsContains(CompleteResponse response, String completion) =>
    response.completions.any((map) => map['completion'] == completion);
