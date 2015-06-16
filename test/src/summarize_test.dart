// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// These tests serve to determine the functionality of the summarization tool.
library dartpad.summarize_test;

import 'package:dart_pad/services/dartservices.dart';
import 'package:dart_pad/src/summarize.dart';
import 'package:test/test.dart';

main() => defineTests();

void defineTests() {
  group('Summarizer helpers', () {
    test('Unique case detection in list', () {
      Summarizer summer = new Summarizer(dart: 'pirate');
      expect(summer.additionSearch(), contains('pirates'));
    });

    test('Unique case detection no false triggers in list', () {
      Summarizer summer = new Summarizer(dart: 'll not amma, pir not ates');
      expect(summer.additionSearch(), isNot(contains('pirates')));
      expect(summer.additionSearch(), isNot(contains('dogs')));
      expect(summer.additionSearch(), isNot(contains('birds')));
      expect(summer.additionSearch(), isNot(contains('llamas')));
    });
  });

  group('Summarizer', () {
    test('AnalysisResults present', () {
      AnalysisIssue issue = new AnalysisIssue();
      issue.kind = 'error';
      issue.message = 'foo';
      issue.sourceName = 'main.dart';
      AnalysisResults results = new AnalysisResults();
      results.issues = [issue];
      results.packageImports = [];
      results.resolvedImports = [];
      Summarizer summer1 = new Summarizer(dart: 'Test.', analysis: results);
      Summarizer summer2 = new Summarizer(dart: 'Test.');
      expect(summer1.returnAsSimpleSummary(),
          isNot(equals(summer2.returnAsSimpleSummary())));
    });

    test('Non-null input does not fail', () {
      Summarizer summer = new Summarizer(dart: 'Test.');
      expect(summer.returnAsSimpleSummary(), isNotNull);
    });

    test('returnAsMarkDown', () {
      Summarizer summer = new Summarizer(dart: 'Test.');
      expect(summer.returnAsMarkDown(), isNotNull);
    });

    test('Null throws ArgumentError', () {
      expect(() => new Summarizer(), throwsArgumentError);
    });

    test('Same input causes same output', () {
      Summarizer summer1 = new Summarizer(dart: 'Test case one.');
      Summarizer summer2 = new Summarizer(dart: 'Test case one.');
      expect(summer1.returnAsSimpleSummary(),
          equals(summer2.returnAsSimpleSummary()));
    });

    test('Unique case detection', () {
      Summarizer summer = new Summarizer(dart: 'pirate');
      expect(summer.returnAsSimpleSummary(), contains('pirates'));
    });

    test('Unique case detection', () {
      Summarizer summer = new Summarizer(dart: "pirate, dog, bird, llama");
      expect(summer.returnAsSimpleSummary(), contains('pirates'));
      expect(summer.returnAsSimpleSummary(), contains('dogs'));
      expect(summer.returnAsSimpleSummary(), contains('birds'));
      expect(summer.returnAsSimpleSummary(), contains('llamas'));
    });

    test('Unique case detection no false triggers', () {
      Summarizer summer = new Summarizer(dart: 'll not amma, pir not ates');
      expect(summer.returnAsSimpleSummary(), isNot(contains('pirates')));
      expect(summer.returnAsSimpleSummary(), isNot(contains('dogs')));
      expect(summer.returnAsSimpleSummary(), isNot(contains('birds')));
      expect(summer.returnAsSimpleSummary(), isNot(contains('llamas')));
    });

    test('Modification causes change', () {
      Summarizer summer1 =
          new Summarizer(dart: "this does not return anything");
      Summarizer summer2 = new Summarizer(dart: "this doesnt return anything");
      expect(summer1.returnAsSimpleSummary(),
          isNot(summer2.returnAsSimpleSummary()));
    });

    test('Same input same output', () {
      Summarizer summer1 =
          new Summarizer(dart: 'this does not return anything');
      Summarizer summer2 =
          new Summarizer(dart: 'this does not return anything');
      expect(summer1.returnAsSimpleSummary(),
          equals(summer2.returnAsSimpleSummary()));
    });

    test('Html and css detection', () {
      Summarizer summer1 =
          new Summarizer(dart: 'this does not return anything', html: '<div/>');
      Summarizer summer2 =
          new Summarizer(dart: 'this does not return anything');
      expect(summer1.returnAsSimpleSummary(),
          isNot(equals(summer2.returnAsSimpleSummary())));
    });
  });
}
