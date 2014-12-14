
library mock_analysis;

import 'dart:async';

import 'common.dart';
import '../analysis.dart';
import '../dependencies.dart';
import '../modules.dart';

class MockAnalysisModule extends Module {
  MockAnalysisModule();

  Future init() {
    deps[AnalysisIssueService] = new MockAnalysisIssueService();
    return new Future.value();
  }
}

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
