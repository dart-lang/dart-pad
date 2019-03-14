// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// All classes exported over the RPC protocol.
library services.api_classes;

import 'dart:convert';

import 'package:rpc/rpc.dart';

class AnalysisResults {
  final List<AnalysisIssue> issues;

  @ApiProperty(description: 'The package imports parsed from the source.')
  final List<String> packageImports;

  AnalysisResults(this.issues, this.packageImports);
}

class AnalysisIssue implements Comparable<AnalysisIssue> {
  final String kind;
  final int line;
  final String message;
  final String sourceName;

  final bool hasFixes;

  final int charStart;
  final int charLength;

  AnalysisIssue.fromIssue(this.kind, this.line, this.message,
      {this.charStart,
      this.charLength,
      this.sourceName,
      this.hasFixes = false});

  Map toMap() {
    Map m = {'kind': kind, 'line': line, 'message': message};
    if (charStart != null) m['charStart'] = charStart;
    if (charLength != null) m['charLength'] = charLength;
    if (hasFixes != null) m['hasFixes'] = hasFixes;
    if (sourceName != null) m['sourceName'] = sourceName;

    return m;
  }

  @override
  int compareTo(AnalysisIssue other) => line - other.line;

  @override
  String toString() => '${kind}: ${message} [${line}]';
}

class SourceRequest {
  @ApiProperty(required: true, description: 'The Dart source.')
  String source;

  @ApiProperty(description: 'An optional offset into the source code.')
  int offset;

  @ApiProperty(description: 'Ignored: always treated as true.')
  @deprecated
  bool strongMode;
}

class SourcesRequest {
  @ApiProperty(required: true, description: 'Map of names to Sources.')
  Map<String, String> sources;

  @ApiProperty(description: 'An optional location in the source code.')
  Location location;

  @ApiProperty(description: 'Ignored: always treated as true.')
  @deprecated
  bool strongMode;
}

class Location {
  String sourceName;
  int offset;

  Location();
  Location.from(this.sourceName, this.offset);
}

class CompileRequest {
  @ApiProperty(required: true, description: 'The Dart source.')
  String source;

  @ApiProperty(
      description:
          'Return the Dart to JS source map; optional (defaults to false).')
  bool returnSourceMap;
}

class CompileResponse {
  final String result;
  final String sourceMap;

  CompileResponse(this.result, [this.sourceMap]);
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
  @ApiProperty(
      description: 'The offset of the start of the text to be replaced.')
  final int replacementOffset;

  @ApiProperty(description: 'The length of the text to be replaced.')
  final int replacementLength;

  final List<Map<String, String>> completions;

  CompleteResponse(
      this.replacementOffset, this.replacementLength, List<Map> completions)
      : this.completions = _convert(completions);

  /// Convert any non-string values from the contained maps.
  static List<Map<String, String>> _convert(List<Map> list) {
    return list.map<Map<String, String>>((m) {
      Map<String, String> newMap = {};
      for (String key in m.keys) {
        var data = m[key];
        // TODO: Properly support Lists, Maps (this is a hack).
        if (data is Map || data is List) {
          data = json.encode(data);
        }
        newMap[key] = '${data}';
      }
      return newMap;
    }).toList();
  }
}

class FixesResponse {
  final List<ProblemAndFixes> fixes;

  FixesResponse(this.fixes);
}

/// Represents a problem detected during analysis, and a set of possible
/// ways of resolving the problem.
class ProblemAndFixes {
  // TODO(lukechurch): consider consolidating this with [AnalysisIssue]
  final List<CandidateFix> fixes;
  final String problemMessage;
  final int offset;
  final int length;

  ProblemAndFixes() : this.fromList([]);
  ProblemAndFixes.fromList(
      [this.fixes, this.problemMessage, this.offset, this.length]);
}

/// Represents a possible way of solving an Analysis Problem.
class CandidateFix {
  final String message;
  final List<SourceEdit> edits;

  CandidateFix() : this.fromEdits();
  CandidateFix.fromEdits([this.message, this.edits]);
}

/// Represents a reformatting of the code.
class FormatResponse {
  @ApiProperty(description: 'The formatted source code.')
  final String newString;

  @ApiProperty(
      description: 'The (optional) new offset of the cursor; can be `null`.')
  final int offset;

  FormatResponse(this.newString, [this.offset = 0]);
}

/// Represents a single edit-point change to a source file.
class SourceEdit {
  final int offset;
  final int length;
  final String replacement;

  SourceEdit() : this.fromChanges();
  SourceEdit.fromChanges([this.offset, this.length, this.replacement]);

  String applyTo(String target) {
    if (offset >= replacement.length) {
      throw "Offset beyond end of string";
    } else if (offset + length >= replacement.length) {
      throw "Change beyond end of string";
    }

    String pre = "${target.substring(0, offset)}";
    String post = "${target.substring(offset + length)}";
    return "$pre$replacement$post";
  }
}

/// The response from the `/version` service call.
class VersionResponse {
  @ApiProperty(
      description: 'The Dart SDK version that DartServices is compatible with. '
          'This will be a semver string.')
  final String sdkVersion;

  @ApiProperty(
      description:
          'The full Dart SDK version that DartServices is compatible with.')
  final String sdkVersionFull;

  @ApiProperty(
      description: 'The Dart SDK version that the server is running on. This '
          'will start with a semver string, and have a space and other build '
          'details appended.')
  final String runtimeVersion;

  @ApiProperty(description: 'The App Engine version.')
  final String appEngineVersion;

  @ApiProperty(description: 'The dart-services backend version.')
  final String servicesVersion;

  VersionResponse(
      {this.sdkVersion,
      this.sdkVersionFull,
      this.runtimeVersion,
      this.appEngineVersion,
      this.servicesVersion});
}
