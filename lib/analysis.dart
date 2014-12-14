
library dartpad_ui.analysis;

import 'dart:async';

// TODO: code completion

// TODO: dartdoc hover

abstract class AnalysisIssueService {
  Future<AnalysisResults> analyze(String source);
}

class AnalysisResults {
  final List<AnalysisIssue> issues;

  AnalysisResults(this.issues);

  String toString() => '${issues}';
}

class AnalysisIssue {
  final String kind;
  final int line;
  final String message;
  final int charStart;
  final int charLength;

  AnalysisIssue(this.kind, this.line, this.message,
      {this.charStart, this.charLength});

  String toString() => '[${kind}, line ${line}] ${message}';
}
