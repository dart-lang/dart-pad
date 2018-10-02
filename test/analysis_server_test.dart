// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer_server_test;

import 'package:dart_services/src/analysis_server.dart';
import 'package:dart_services/src/api_classes.dart';
import 'package:dart_services/src/common.dart';
import 'package:test/test.dart';

String completionCode = r'''
void main() {
  int i = 0;
  i.
}
''';

String completionFilterCode = r'''
void main() {
  pr
}
''';

String quickFixesCode = r'''
void main() {
  int i = 0
}
''';

String badFormatCode = r'''
void main()
{
int i = 0;
}
''';

String formattedCode = r'''
void main() {
  int i = 0;
}
''';

String formatWithIssues = '''
void main() { foo() }
''';

void main() => defineTests();

void defineTests() {
  AnalysisServerWrapper analysisServer;

  group('analysis_server', () {
    setUp(() async {
      analysisServer = AnalysisServerWrapper(sdkPath);
      await analysisServer.init();
    });

    tearDown(() => analysisServer.shutdown());

    test('simple_completion', () {
      //Just after i.
      return analysisServer
          .complete(completionCode, 32)
          .then((CompleteResponse results) {
        expect(results.replacementLength, 0);
        expect(results.replacementOffset, 32);
        expect(completionsContains(results, "abs"), true);
        expect(completionsContains(results, "codeUnitAt"), false);
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
          expect(completionsContains(results, "print"), true);
          expect(completionsContains(results, "pow"), false);
        });
      });
    });

    test('import_test', () {
      String testCode = "import '/'; main() { int a = 0; a. }";

      //Just after i.
      return analysisServer
          .complete(testCode, 9)
          .then((CompleteResponse results) {
        expect(results.completions.every((Map<String, String> completion) {
          return completion["completion"].startsWith("dart:");
        }), true);
      });
    });

    test('import_and_other_test', () {
      String testCode = "import '/'; main() { int a = 0; a. }";

      //Just after i.
      return analysisServer
          .complete(testCode, 34)
          .then((CompleteResponse results) {
        expect(completionsContains(results, "abs"), true);
      });
    });

    test('simple_quickFix', () {
      //Just after i.
      return analysisServer
          .getFixes(quickFixesCode, 25)
          .then((FixesResponse results) {
        expect(results.fixes.length, 1);
        expect(results.fixes[0].offset, 24);
        expect(results.fixes[0].length, 1); //we need an insertion

        // We should be getting an insert ; fix
        expect(results.fixes[0].fixes.length, 1);
        CandidateFix fix = results.fixes[0].fixes[0];
        expect(fix.message.contains(";"), true);
        expect(fix.edits[0].length, 0);
        expect(fix.edits[0].offset, 25);
        expect(fix.edits[0].replacement, ";");
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

    test('analyze preview-dart-2', () async {
      await analysisServer.shutdown();

      analysisServer = AnalysisServerWrapper(sdkPath, previewDart2: true);
      await analysisServer.init();
      AnalysisResults results =
          await analysisServer.analyze(samplePreviewDart2OK);
      expect(results.issues, hasLength(0));
    });

    test('analyze no-preview-dart-2', () async {
      await analysisServer.shutdown();

      analysisServer = AnalysisServerWrapper(sdkPath, previewDart2: false);
      await analysisServer.init();
      AnalysisResults results =
          await analysisServer.analyze(samplePreviewDart2OK);
      expect(results.issues, hasLength(1));
      AnalysisIssue issue = results.issues.first;
      expect(issue.kind, 'error');
    }, skip: 'no-preview-dart-2 support needs to be removed entirely');
  });
}

bool completionsContains(CompleteResponse response, String completion) =>
    response.completions.any((map) => map["completion"] == completion);
