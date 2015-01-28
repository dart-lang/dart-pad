// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_ui.analysis;

import 'dart:async';

// TODO: code completion

abstract class AnalysisService {
  Future<AnalysisResults> analyze(String source);

  /**
   * Get dartdoc documentation for the element at the given offset. The returned
   * map contains fields `name`, `description`, `kind`, `libraryName`,
   * `staticType`, and `dartdoc`. Note that the `dartdoc` field is in markdown
   * format.
   */
  Future<Map> getDocumentation(String source, int offset);
}

class AnalysisResults {
  final List<AnalysisIssue> issues;

  AnalysisResults(this.issues);

  bool get hasError => issues.any((i) => i.kind == 'error');
  bool get hasWarning => issues.any((i) => i.kind == 'warning');
  bool get hasInfo => issues.any((i) => i.kind == 'info');

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
