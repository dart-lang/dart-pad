// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer_test;

import 'package:services/src/analyzer.dart';
import 'package:services/src/common.dart';
import 'package:grinder/grinder.dart' as grinder;
import 'package:unittest/unittest.dart';

String sdkPath = grinder.getSdkDir().path;

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
  });
}
