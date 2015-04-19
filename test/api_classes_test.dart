// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.api_classes_test;

import 'package:services/src/api_classes.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('AnalysisIssue', () {
    test('toMap', () {
      AnalysisIssue issue = new AnalysisIssue('error', 1, 'not found',
          charStart: 123);
      Map m = issue.toMap();
      expect(m['kind'], 'error');
      expect(m['line'], 1);
      expect(m['message'], isNotNull);
      expect(m['charStart'], isNotNull);
      expect(m['charLength'], isNull);
    });

    test('toString', () {
      AnalysisIssue issue = new AnalysisIssue('error', 1, 'not found');
      expect(issue.toString(), isNotNull);
    });
  });
}
