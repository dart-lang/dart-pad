// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_ui.analysis_mock;

import 'dart:async';

import 'common.dart';
import 'analysis.dart';

export 'analysis.dart';

class MockAnalysisIssueService implements AnalysisIssueService {
  Future<AnalysisResults> analyze(String source) {
    Lines lines = new Lines(source);
    List<AnalysisIssue> issues = 'todo'.allMatches(source).map((Match match) {
      return new AnalysisIssue(
          'todo', lines.getLineForOffset(match.start) + 1, "found a todo");
    }).toList();

    return new Future.delayed(
        new Duration(milliseconds: 500), () => new AnalysisResults(issues));
  }
}
