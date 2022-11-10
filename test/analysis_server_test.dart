// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer_server_test;

import 'dart:io';

import 'package:dart_services/src/analysis_server.dart';
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/protos/dart_services.pb.dart' as proto;
import 'package:dart_services/src/sdk.dart';
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

const lintWarningTrigger = '''
void main() async {
  var unknown;
  print(unknown);
}
''';

final channel = Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel;

void main() => defineTests();

void defineTests() {
  late AnalysisServerWrapper analysisServer;

  /// Returns whether the completion [response] contains [expected].
  bool completionsContains(proto.CompleteResponse response, String expected) =>
      response.completions
          .any((completion) => completion.completion['completion'] == expected);

  group('Platform SDK analysis_server', () {
    late Sdk sdk;
    setUp(() async {
      sdk = Sdk.create(channel);
      analysisServer = DartAnalysisServerWrapper(dartSdkPath: sdk.dartSdkPath);
      await analysisServer.init();
    });

    tearDown(() => analysisServer.shutdown());

    test('simple_completion', () async {
      // Just after `i.` on line 3 of [completionCode]
      final results = await analysisServer.complete(completionCode, 32);
      expect(results.replacementLength, 0);
      expect(results.replacementOffset, 32);
      final completions =
          results.completions.map((c) => c.completion['completion']).toList();
      expect(completions, contains('abs'));
      expect(completionsContains(results, 'codeUnitAt'), false);
    });

    // https://github.com/dart-lang/dart-pad/issues/2005
    test('Trigger lint with Dart code', () async {
      final results = await analysisServer.analyze(lintWarningTrigger);
      expect(results.issues.length, 1);
      final issue = results.issues[0];
      expect(issue.line, 2);
      expect(issue.kind, 'info');
      if (sdk.channel == 'master') {
        expect(issue.message,
            'An uninitialized variable should have an explicit type annotation.');
      } else {
        expect(
            issue.message, 'Prefer typing uninitialized variables and fields.');
      }
    });

    test('repro #126 - completions polluted on second request', () async {
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

    test('import_test', () async {
      // We're testing here that we don't have any path imports - we don't want
      // to enable browsing the file system.
      final testCode = "import '/'; main() { int a = 0; a. }";
      final results = await analysisServer.complete(testCode, 9);
      final completions = results.completions;

      if (completions.isNotEmpty) {
        expect(completions.every((completion) {
          return completion.completion['completion']!.startsWith('dart:');
        }), true);
      }
    });

    test('import_dart_core_test', () async {
      // Ensure we can import dart: imports.
      final testCode = "import 'dart:c'; main() { int a = 0; a. }";

      final results = await analysisServer.complete(testCode, 14);
      final completions = results.completions;

      expect(
        completions.every((completion) =>
            completion.completion['completion']!.startsWith('dart:')),
        true,
      );
      expect(
        completions.any((completion) =>
            completion.completion['completion']!.startsWith('dart:')),
        true,
      );
    });

    test('import_and_other_test', () async {
      final testCode = "import '/'; main() { int a = 0; a. }";
      final results = await analysisServer.complete(testCode, 34);

      expect(completionsContains(results, 'abs'), true);
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
      final sdk = Sdk.create(channel);
      analysisServer =
          FlutterAnalysisServerWrapper(dartSdkPath: sdk.dartSdkPath);
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

  //--------------------------------------------------------
  // Begin testing the multi file group files={} map entry points:
  group('Platform SDK analysis_server multifile files={}', () {
    late Sdk sdk;
    setUp(() async {
      sdk = Sdk.create(channel);
      analysisServer = DartAnalysisServerWrapper(dartSdkPath: sdk.dartSdkPath);
      await analysisServer.init();
    });

    tearDown(() => analysisServer.shutdown());

    // Now test multi file 'files:{}' source format.
    const kMainDart = 'main.dart';

    test('files={} simple_completion', () async {
      // Just after `i.` on line 3 of [completionCode]
      final results = await analysisServer
          .completeFiles({kMainDart: completionCode}, Location(kMainDart, 32));
      expect(results.replacementLength, 0);
      expect(results.replacementOffset, 32);
      final completions =
          results.completions.map((c) => c.completion['completion']).toList();
      expect(completions, contains('abs'));
      expect(completionsContains(results, 'codeUnitAt'), false);
    });

    // https://github.com/dart-lang/dart-pad/issues/2005
    test('files={} Trigger lint with Dart code', () async {
      final results =
          await analysisServer.analyzeFiles({kMainDart: lintWarningTrigger});
      expect(results.issues.length, 1);
      final issue = results.issues[0];
      expect(issue.line, 2);
      expect(issue.kind, 'info');
      if (sdk.channel == 'master') {
        expect(issue.message,
            'An uninitialized variable should have an explicit type annotation.');
      } else {
        expect(
            issue.message, 'Prefer typing uninitialized variables and fields.');
      }
    });

    test('files={} repro #126 - completions polluted on second request',
        () async {
      final Map<String, String> files = {kMainDart: completionFilterCode};
      final Location location = Location(kMainDart, 17);
      // https://github.com/dart-lang/dart-services/issues/126
      return analysisServer.completeFiles(files, location).then((results) {
        return analysisServer.completeFiles(files, location).then((results) {
          expect(results.replacementLength, 2);
          expect(results.replacementOffset, 16);
          expect(completionsContains(results, 'print'), true);
          expect(completionsContains(results, 'pow'), false);
        });
      });
    });

    test('files={} import_test', () async {
      // We're testing here that we don't have any path imports - we don't want
      // to enable browsing the file system.
      final testCode = "import '/'; main() { int a = 0; a. }";

      final results = await analysisServer
          .completeFiles({kMainDart: testCode}, Location(kMainDart, 9));
      final completions = results.completions;

      if (completions.isNotEmpty) {
        expect(completions.every((completion) {
          return completion.completion['completion']!.startsWith('dart:');
        }), true);
      }
    });

    test('files={} import_dart_core_test', () async {
      // Ensure we can import dart: imports.
      final testCode = "import 'dart:c'; main() { int a = 0; a. }";

      final results = await analysisServer
          .completeFiles({kMainDart: testCode}, Location(kMainDart, 14));
      final completions = results.completions;

      expect(
        completions.every((completion) =>
            completion.completion['completion']!.startsWith('dart:')),
        true,
      );
      expect(
        completions.any((completion) =>
            completion.completion['completion']!.startsWith('dart:')),
        true,
      );
    });

    test('files={} import_and_other_test', () async {
      final testCode = "import '/'; main() { int a = 0; a. }";

      final results = await analysisServer
          .completeFiles({kMainDart: testCode}, Location(kMainDart, 34));

      expect(completionsContains(results, 'abs'), true);
    });

    test('files={} myRandomName.dart + simple_quickFix', () async {
      final results = await analysisServer.getFixesMulti(
          {'myRandomName.dart': quickFixesCode},
          Location('myRandomName.dart', 25));

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

    test('files={} analyze', () async {
      final results =
          await analysisServer.analyzeFiles({kMainDart: sampleCode});
      expect(results.issues, isEmpty);
    });

    test('files={} analyze with errors', () async {
      final results =
          await analysisServer.analyzeFiles({kMainDart: sampleCodeError});
      expect(results.issues, hasLength(1));
    });

    test('files={} filter completions', () async {
      // just after A
      final idx = 61;
      expect(completionLargeNamespaces.substring(idx - 1, idx), 'A');
      final results = await analysisServer.completeFiles(
          {kMainDart: completionLargeNamespaces}, Location(kMainDart, 61));
      expect(completionsContains(results, 'A'), true);
      expect(completionsContains(results, 'AB'), true);
      expect(completionsContains(results, 'ABC'), true);
      expect(completionsContains(results, 'a'), true);
      expect(completionsContains(results, 'ZZ'), false);
    });
  });
}
