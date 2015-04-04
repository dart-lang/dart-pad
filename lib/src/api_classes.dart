// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.api_classes;

import 'dart:convert';

import 'package:rpc/rpc.dart';
import 'package:analysis_server/src/protocol.dart';

class AnalysisResults {
  final List<AnalysisIssue> issues;

  AnalysisResults(this.issues);
}

class AnalysisIssue implements Comparable {
  final String kind;
  final int line;
  final String message;

  final int charStart;
  final int charLength;
  final String location;

  AnalysisIssue(this.kind, this.line, this.message,
      {this.charStart, this.charLength, this.location});

  Map toMap() {
    Map m = {'kind': kind, 'line': line, 'message': message};
    if (charStart != null) m['charStart'] = charStart;
    if (charLength != null) m['charLength'] = charLength;
    return m;
  }

  int compareTo(AnalysisIssue other) => line - other.line;

  String toString() => '${kind}: ${message} [${line}]';
}

class SourceRequest {
  @ApiProperty(required: true)
  String source;
  int offset;
}

class CompileResponse {
  final String result;

  CompileResponse(this.result);
}

class CounterRequest {
  @ApiProperty(required: true)
  String name;
}

class CounterResponse {
  final int count;

  CounterResponse(this.count);
}

class DocumentResponse {
  final Map<String, String> info;

  DocumentResponse(this.info);
}


class CompleteResponse {
  @ApiProperty(description: 'The offset of the start of the text to be replaced.')
  final int replacementOffset;

  @ApiProperty(description: 'The length of the text to be replaced.')
  final int replacementLength;

  final List<Map<String, String>> completions;

  CompleteResponse(this.replacementOffset, this.replacementLength,
      List<Map> completions) :
    this.completions = _convert(completions);

  /**
   * Convert any non-string values from the contained maps.
   */
  static List<Map<String, String>> _convert(List<Map> list) {
    return list.map((m) {
      Map newMap = {};
      for (String key in m.keys) {
        var data = m[key];
        // TODO: Properly support Lists, Maps (this is a hack).
        if (data is Map || data is List) {
          data = JSON.encode(data);
        }
        newMap[key] = '${data}';
      }
      return newMap;
    }).toList();
  }
}

class FixesResponse {
  final List<ProblemFix> fixes;

  FixesResponse(List<AnalysisErrorFixes> analysisErrorFixes) :
    this.fixes = _convert(analysisErrorFixes);

  /**
   * Convert any non-string values from the contained maps.
   */
  static List<ProblemFix> _convert(List<AnalysisErrorFixes> list) {
    var problemsAndFixes = new List<ProblemFix>();
    list.forEach((analysisErrorFix)
        => problemsAndFixes.add(_convertAnalysisErrorFix(analysisErrorFix)));

    return problemsAndFixes;
  }

  static ProblemFix _convertAnalysisErrorFix(AnalysisErrorFixes analysisErrFix) {
    String problemMessage = analysisErrFix.error.message;
    int problemOffset = analysisErrFix.error.location.offset;
    int problemLength = analysisErrFix.error.location.length;

    List<Fix> possibleFixes = new List<Fix>();

    for (var sourceChange in analysisErrFix.fixes) {
      List<Edit> edits = new List<Edit>();
      for (var sourceFileEdit in sourceChange.edits) {
        for (var sourceEdit in sourceFileEdit.edits) {
          edits.add(new Edit(
              sourceEdit.offset,
              sourceEdit.length,
              sourceEdit.replacement));
        }
      }
      Fix possibleFix = new Fix(sourceChange.message, edits);
      possibleFixes.add(possibleFix);
    }
    return new ProblemFix(
        possibleFixes,
        problemMessage,
        problemOffset,
        problemLength);
  }
}

/// Set of fixes for a particular problem.
class ProblemFix {
  final List<Fix> fixes;
  final String problemMessage;
  final int offset;
  final int length;

  ProblemFix(this.fixes, this.problemMessage, this.offset, this.length);
}

/// A single way of fixing a particular problem
class Fix {
  final String message;
  final List<Edit> edits;

  Fix(this.message, this.edits);
}

class Edit {
  final int offset;
  final int length;
  final String replacement;

  Edit(this.offset, this.length, this.replacement);
}
