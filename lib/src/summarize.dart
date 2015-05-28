// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.summarize;

import '../services/dartservices.dart';
/// Instances of this class take string input of dart code as well as an analysis result,
/// and output a text description ofthe code's size, packages, and other useful information.
class Summarizer {
  
  SummarizeToken storage;

  bool resultsPresent;
  
  Summarizer(String input, [AnalysisResults analysis]) {
    if (input == null) throw new ArgumentError("Input can't be null.");
    resultsPresent = !(analysis == null);
    storage = new SummarizeToken(input, analysis);
  }
  
  String returnAsSimpleSummary() {
    String summary = 'Summary (Under Development):';
    return summary;
  }
  
  String returnAsGistMarkDown() {
    if (resultsPresent) {
      String summary = '<pre><code><b>Summary (Under Development)</b><p/>';
      summary +='${storage.linesCode} lines of code. <p/>';
      if (storage.errorPresent) summary += 'Errors are present.<p/>';
      if (storage.errorPresent) summary += 'Warnings are present.<p/>';
      summary += '${storage.features} <p/>';
      summary += '${storage.packageCount} Package Imports: ${storage.packageImports}. <p/>';
      summary += '${storage.resolvedCount} Resolved Imports: ${storage.resolvedImports}. <p/>';
      summary += 'List of ${storage.errorCount} Errors: <ul>';
      for (AnalysisIssue issue in storage.errors) {
        summary += '<li>${_condenseIssue(issue)}</li>';
      }
      summary += '</ul></code></pre>';
      return summary;
    }
    else {
      String summary = '<pre><code><b>Summary (Under Development)</b><p/>';
      summary +='${storage.linesCode} lines of code. <p/>';
      return summary;
    }
    
  }
  
  String _condenseIssue(AnalysisIssue issue) {
    return '''${issue.kind.toUpperCase()} | ${issue.message} </n>
  Source at ${issue.sourceName} <n/>
  Located at line: ${issue.line} <n/>.
  ''';
    }
}

class SummarizeToken {
  int linesCode;
  int packageCount;
  int resolvedCount;
  int errorCount;
  
  bool errorPresent;
  bool warningPresent;
  
  String features;
  
  List<String> packageImports;
  List<String> resolvedImports;
  
  List<AnalysisIssue> errors;
  
  SummarizeToken (String input, [AnalysisResults analysis]) {
    linesCode = _linesCode(input);
    if (analysis != null) {
      errorPresent = analysis.issues.any((issue) => issue.kind == 'error');
      warningPresent = analysis.issues.any((issue) => issue.kind == 'warning');
      features = _languageFeatures(analysis);
      packageCount= analysis.packageImports.length;
      resolvedCount = analysis.resolvedImports.length;
      packageImports = analysis.packageImports;
      resolvedImports = analysis.resolvedImports;
      errors = analysis.issues;
      errorCount = errors.length;
    }
  }
  
  String _languageFeatures(AnalysisResults input) {
    // TODO: Add language features.
    return "Language features under construction.";
  }
   
  int _linesCode(String input) {
    return input.split('\n').length;
  }
}
