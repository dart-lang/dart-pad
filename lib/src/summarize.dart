// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.summarize;

import '../services/dartservices.dart';
/// Instances of this class take string input of dart code and output a text 
/// description ofthe code's size, packages, and other useful information
class Summarizer {
  
  String summarize(SourceRequest input, AnalysisResults result) {
    if (input == null || result == null) {
      return "Summarizer has broken!.";
    }
    String summary = '<pre><code><b>Summary (Under Development)</b><p/>';
    summary += '${_linesCode(input)} lines of code used. <p/>';
    bool hasErrors = result.issues.any((issue) => issue.kind == 'error');
    bool hasWarnings = result.issues.any((issue) => issue.kind == 'warning');
    if (hasErrors) summary += 'Errors are present.<p/>';
    if (hasWarnings) summary += 'Warnings are present.<p/>';
    summary += _languageFeatures(result);
    summary += '${result.packageImports.length} ';
    summary += 'Package Imports: ${result.packageImports.toString()}. <p/>';
    summary += '${result.resolvedImports.length} ';
    summary += 'Resolved Imports: ${result.resolvedImports.toString()}. <p/>';
    summary += 'List of ${result.issues.length} Errors: <ul>';
    for (AnalysisIssue issue in result.issues) {
      summary += '<li>${_condenseIssue(issue)}</li>';
    }
    summary += '</ul></code></pre>';
    return summary;
  }
  
  ///Outputs the language features used
  String _languageFeatures(AnalysisResults input) {
    //TODO: Add language features
    return "Language features under construction. <p/>";
  }
  
  ///Converts an AnalysisIssue into a summarized string
  String _condenseIssue(AnalysisIssue issue) {
    return '''${issue.kind.toUpperCase()} | ${issue.message} </n>
  Source at ${issue.sourceName} <n/>
  Located at line: ${issue.line}<n/>, 
  ''';
  }
  
  ///Returns the number of lines of a source request's source.
  String _linesCode(SourceRequest input) {
    return input.source.split('\n').length.toString();
  }
}

