// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer_server_test;

import 'package:dart_services/src/analysis_server.dart';
import 'package:dart_services/src/protos/dart_services.pb.dart' as proto;
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/sdk_manager.dart';
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

  group('Platform SDK analysis_server', () {
    setUp(() async {
      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
      analysisServer = AnalysisServerWrapper(sdkPath, flutterWebManager);
      await analysisServer.init();
    });

    tearDown(() => analysisServer.shutdown());

    test('simple_completion', () {
      // Just after i.
      return analysisServer.complete(completionCode, 32).then((results) {
        expect(results.replacementLength, 0);
        expect(results.replacementOffset, 32);
        expect(completionsContains(results, 'abs'), true);
        expect(completionsContains(results, 'codeUnitAt'), false);
      });
    });

    test('repro #126 - completions polluted on second request', () {
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

    test('import_test', () {
      final testCode = "import '/'; main() { int a = 0; a. }";

      return analysisServer.complete(testCode, 9).then((results) {
        expect(results.completions.every((completion) {
          return completion.completion['completion'].startsWith('dart:');
        }), true);
      });
    });

    test('import_and_other_test', () {
      final testCode = "import '/'; main() { int a = 0; a. }";

      return analysisServer.complete(testCode, 34).then((results) {
        expect(completionsContains(results, 'abs'), true);
      });
    });

    test('simple_quickFix', () async {
      final results = await analysisServer.getFixes(quickFixesCode, 25);

      expect(results.fixes.length, 2);

      // Fixes are not guaranteed to arrive in a particular order.
      results.fixes.sort((a, b) => a.offset.compareTo(b.offset));

      expect(results.fixes[0].offset, 20);
      expect(results.fixes[0].length, 1); // We need an insertion.

      expect(results.fixes[1].offset, 24);
      expect(results.fixes[1].length, 1); // We need an insertion.

      expect(results.fixes[1].fixes.length, 1);

      final candidateFix = results.fixes[1].fixes[0];

      expect(candidateFix.message.contains(';'), true);
      expect(candidateFix.edits[0].length, 0);
      expect(candidateFix.edits[0].offset, 25);
      expect(candidateFix.edits[0].replacement, ';');
    });

    test('simple_format', () async {
      final results = await analysisServer.format(badFormatCode, 0);
      expect(results.newString, formattedCode);
    });

    test('format good code', () async {
      final results =
          await analysisServer.format(formattedCode.replaceAll('\n', ' '), 0);
      expect(results.newString, formattedCode);
    });

    test('format with issues', () async {
      final results = await analysisServer.format(formatWithIssues, 0);
      expect(results.newString, formatWithIssues);
    });

    test('analyze', () async {
      final results = await analysisServer.analyze(sampleCode);
      expect(results.issues, isEmpty);
    });

    test('analyze with errors', () async {
      final results = await analysisServer.analyze(sampleCodeError);
      expect(results.issues, hasLength(1));
    });

    test('analyze strong', () async {
      final results = await analysisServer.analyze(sampleStrongError);
      expect(results.issues, hasLength(1));
      final issue = results.issues.first;
      expect(issue.kind, 'error');
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
  });

  group('Flutter cached SDK analysis_server', () {
    setUp(() async {
      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
      analysisServer = AnalysisServerWrapper(
          SdkManager.flutterSdk.sdkPath, flutterWebManager);
      await analysisServer.init();
    });

    tearDown(() => analysisServer.shutdown());

    test('analyze working Dart code', () async {
      final results = await analysisServer.analyze(sampleCode);
      expect(results.issues, isEmpty);
    });

    test('analyze working Flutter code', () async {
      final results = await analysisServer.analyze(sampleCode);
      expect(results.issues, isEmpty);
    });
  });
}

bool completionsContains(proto.CompleteResponse response, String expected) =>
    response.completions
        .any((completion) => completion.completion['completion'] == expected);
