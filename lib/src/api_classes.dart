// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// All classes exported over the RPC protocol.
library services.api_classes;

import 'dart:convert';

import 'package:analysis_server/src/protocol.dart';
import 'package:rpc/rpc.dart';

class AnalysisResults {
  final List<AnalysisIssue> issues;

  AnalysisResults(this.issues);
}

class AnalysisIssue implements Comparable {
  final String kind;
  final int line;
  final String message;

  final bool hasFixes;

  final int charStart;
  final int charLength;
  final String location;

  AnalysisIssue(this.kind, this.line, this.message,
      {this.charStart, this.charLength, this.location, this.hasFixes: false});

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
  final List<ProblemAndFixes> fixes;

  FixesResponse(List<AnalysisErrorFixes> analysisErrorFixes) :
    this.fixes = _convert(analysisErrorFixes);

  /**
   * Convert between the Analysis Server type and the API protocol types.
   */
  static List<ProblemAndFixes> _convert(List<AnalysisErrorFixes> list) {
    var problemsAndFixes = new List<ProblemAndFixes>();
    list.forEach((fix)
        => problemsAndFixes.add(_convertAnalysisErrorFix(fix)));

    return problemsAndFixes;
  }

  static ProblemAndFixes _convertAnalysisErrorFix(AnalysisErrorFixes analysisFixes) {
    String problemMessage = analysisFixes.error.message;
    int problemOffset = analysisFixes.error.location.offset;
    int problemLength = analysisFixes.error.location.length;

    List<CandidateFix> possibleFixes = new List<CandidateFix>();

    for (var sourceChange in analysisFixes.fixes) {
      List<SourceEdit> edits = new List<SourceEdit>();

      // A fix that tries to modify other files is considered invalid.

      bool invalidFix = false;
      for (var sourceFileEdit in sourceChange.edits) {

        // TODO(lukechurch): replace this with a more reliable test based
        // on the psuedo file name in Analysis Server
        if (!sourceFileEdit.file.endsWith("/main.dart")) {
          invalidFix = true;
          break;
        }

        for (var sourceEdit in sourceFileEdit.edits) {
          edits.add(new SourceEdit(
              sourceEdit.offset,
              sourceEdit.length,
              sourceEdit.replacement));
        }
      }
      if (!invalidFix) {
        CandidateFix possibleFix = new CandidateFix(sourceChange.message, edits);
        possibleFixes.add(possibleFix);
      }
    }
    return new ProblemAndFixes(
        possibleFixes,
        problemMessage,
        problemOffset,
        problemLength);
  }
}

/**
 * Represents a problem detected during analysis, and a set of possible
 * ways of resolving the problem.
 */
class ProblemAndFixes {
  //TODO(lukechurch): consider consolidating this with [AnalysisIssue]
  final List<CandidateFix> fixes;
  final String problemMessage;
  final int offset;
  final int length;

  ProblemAndFixes(this.fixes, this.problemMessage, this.offset, this.length);
}

/**
 * Represents a possible way of solving an Analysis Problem.
 */
class CandidateFix {
  final String message;
  final List<SourceEdit> edits;

  CandidateFix(this.message, this.edits);
}

/*
 * Represents a reformatting of the code.
 */
class FormatResponse {
  List<SourceEdit> edits;

  FormatResponse(EditFormatResult format) {
    edits = [];

    format.edits.forEach((edit) => edits.add(
      new SourceEdit(edit.offset,
        edit.length != null ? edit.length : 0,
        edit.replacement != null ? edit.replacement : 0)
    ));
  }
}

/**
 * Represents a single edit-point change to a source file.
 */
class SourceEdit {
  final int offset;
  final int length;
  final String replacement;

  SourceEdit(this.offset, this.length, this.replacement);

}
