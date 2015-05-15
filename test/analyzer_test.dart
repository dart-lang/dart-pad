// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer_test;

import 'package:services/src/analyzer.dart';
import 'package:services/src/common.dart';
import 'package:cli_util/cli_util.dart' as cli_util;
import 'package:unittest/unittest.dart';

import 'package:services/src/api_classes.dart';

String sdkPath = cli_util.getSdkDir([]).path;

void defineTests() {
  Analyzer analyzer;

  group('analyzer.analyze', () {
    setUp(() {
      analyzer = new Analyzer(sdkPath);
    });

    test('simple', () {
      return analyzer.analyze(sampleCode).then((AnalysisResults results) {
        expect(results.issues, isEmpty);
      });
    });

    test('simple', () {
      return analyzer.analyze(sampleCodeWeb).then((AnalysisResults results) {
        expect(results.issues, isEmpty);
      });
    });

    test('async', () {
      return analyzer.analyze(sampleCodeAsync).then((AnalysisResults results) {
        expect(results.issues, isEmpty);
      });
    });

    test('errors', () {
      return analyzer.analyze(sampleCodeError).then((AnalysisResults results) {
        expect(results.issues.length, 1);
      });
    });

    test('errors many', () {
      return analyzer.analyze(sampleCodeErrors).then((AnalysisResults results) {
        expect(results.issues.length, 3);
      });
    });

    test('missing ;', () {
      final String sample = "void main() {\n  int i = 55\n}";
      return analyzer.analyze(sample).then((AnalysisResults results) {
        expect(results.issues.length, 2);
        int _missingSemiC = 0;
        results.issues
            .where((issue) => issue.message == "Expected to find ';'")
            .forEach((issue) {
          _missingSemiC++;
          expect(issue.hasFixes, true);
        });
        expect(_missingSemiC, 1);
      });
    });

    test('no fixes', () {
      return analyzer.analyze(r'''#''').then((AnalysisResults results) {
        expect(results.issues.length, 2);
        results.issues.forEach((issue) => expect(issue.hasFixes, false));
      });
    });
  });

  group('analyzer.dartdoc', () {
    setUp(() {
      analyzer = new Analyzer(sdkPath);
    });

    test('simple', () {
      return analyzer.dartdoc(sampleCode, 17).then((Map m) {
        expect(m['name'], 'print');
        expect(m['dartdoc'], isNotEmpty);
      });
    });

    test('propagated', () {
      final String source = '''
void main() {
  var foo = 'abc def';
  print(foo);
}
''';

      return analyzer.dartdoc(source, 47).then((Map m) {
        expect(m['name'], 'foo');
        expect(m['propagatedType'], 'String');
      });
    });

    test('future pretified', () {
      final String source = '''
import 'dart:async';

void main() {
  foo
}

Future foo() => new Future.value(4);
''';

      return analyzer.dartdoc(source, 39).then((Map m) {
        expect(m['name'], 'foo');
        expect(m['description'], 'foo() → Future');
        expect(m['staticType'], '() → Future');
      });
    });

    test('dart:html', () {
      final String source = '''
import 'dart:html';
void main() {
  DivElement div = new DivElement();
  print(div);
}
''';

      return analyzer.dartdoc(source, 44).then((Map m) {
        expect(m['name'], 'DivElement');
        expect(m['libraryName'], 'dart:html');
        expect(m['DomName'], 'HTMLDivElement');
      });
    });

    test('simple Multi', () {
      Map sourceMap = {};
      sourceMap.putIfAbsent("foo.dart", () => sampleCodeMultiFoo);
      sourceMap.putIfAbsent("bar.dart", () => sampleCodeMultiBar);

      return analyzer.analyzeMulti(sourceMap).then((AnalysisResults results) {
        expect(results.issues, isEmpty);
      });
    });

    test('multi with error', () {
      Map sourceMap = {};
      sourceMap.putIfAbsent("foo.dart", () => sampleCodeMultiFoo);
      sourceMap.putIfAbsent("bar.dart", () => sampleCodeMultiBar);
      sourceMap.putIfAbsent("main.dart", () => sampleCodeError);

      return analyzer.analyzeMulti(sourceMap).then((AnalysisResults results) {
        expect(results.issues, isNotEmpty);
        expect(results.issues[0].fullName, "main.dart");
      });
    });

    test('multi file missing import', () {
      Map sourceMap = {};
      sourceMap.putIfAbsent("foo.dart", () => sampleCodeMultiFoo);

      return analyzer.analyzeMulti(sourceMap).then((AnalysisResults results) {
        expect(results.issues, isNotEmpty);
        expect(results.issues[0].fullName, "foo.dart");
      });
    });

    test('multi file clean between operation', () {
      Map sourceMap = {};
      sourceMap.putIfAbsent("foo.dart", () => sampleCodeMultiFoo);
      sourceMap.putIfAbsent("bar.dart", () => sampleCodeMultiBar);

      return analyzer.analyzeMulti(sourceMap).then((AnalysisResults results) {
        expect(results.issues, isEmpty);

        sourceMap.remove("bar.dart");
        return analyzer.analyzeMulti(sourceMap).then((AnalysisResults results) {
          expect((results.issues), isNotEmpty);
        });
      });
    });
  });

  group('cleanDartDoc', () {
    test('null', () {
      expect(cleanDartDoc(null), null);
    });

    test('1 line', () {
      expect(cleanDartDoc("/**\n * Foo.\n */\n"), "Foo.");
    });

    test('2 lines', () {
      expect(cleanDartDoc("/**\n * Foo.\n * Foo.\n */\n"), "Foo.\nFoo.");
    });

    test('C# comments', () {
      expect(cleanDartDoc("/// Foo.\n /// Foo.\n"), "Foo.\nFoo.");
    });

    test('bold markdown', () {
      expect(
          cleanDartDoc('/**\n * *Deprecated*: override [attached] instead.\n */'),
          '*Deprecated*: override [attached] instead.');
    });

    test('bold markdown single line', () {
      expect(
          cleanDartDoc('/** *Deprecated*: override [attached] instead. */'),
          '*Deprecated*: override [attached] instead.');
    });
  });
}
