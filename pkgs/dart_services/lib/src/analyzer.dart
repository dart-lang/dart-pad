// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Entrypoint for uses of package:analyzer.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/doc_comment.dart' show DocImport;
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

export 'package:analyzer/dart/ast/ast.dart'
    show
        Directive,
        ExportDirective,
        ImportDirective,
        LibraryDirective,
        PartDirective,
        PartOfDirective,
        UriBasedDirective;

/// Extract all imports from [dartSource] source code.
List<ImportDirective> getAllImportsFor(String dartSource) =>
    getAllDirectivesFor(dartSource).whereType<ImportDirective>().toList();

/// Extracts all directives from [dartSource] source code.
List<Directive> getAllDirectivesFor(String dartSource) =>
    _parse(dartSource).directives.toList();

/// Returns the directives in [dartSource] that DartPad cannot process.
///
/// See [isSafeDirective].
List<Directive> getUnsafeDirectives(String dartSource) => [
  for (final directive in getAllDirectivesFor(dartSource))
    if (!isSafeDirective(directive)) directive,
];

/// Whether [directive] only references URIs that DartPad can process.
///
/// Imports and exports are safe when their URI and every configuration URI
/// satisfy [isSafeUri]. Parts are never safe, because a DartPad program is a
/// single library.
///
/// This is a structural check. Whether DartPad supports the referenced library
/// or package is reported separately by the analysis.
bool isSafeDirective(Directive directive) => switch (directive) {
  LibraryDirective() => !_hasStringLiteral(directive),
  NamespaceDirective(:final uri, :final configurations) =>
    isSafeUri(uri.stringValue) &&
        configurations.every(
          (configuration) => isSafeUri(configuration.uri.stringValue),
        ),
  PartDirective() || PartOfDirective() => false,
};

/// Whether [uri] is a well-formed `dart:` or `package:` URI.
///
/// Incomplete URIs that occur while typing, like `dart:`, `package:`, and
/// `package:flutter/`, are also accepted.
bool isSafeUri(String? uri) {
  if (uri == null) return false;
  if (uri.startsWith('dart:')) {
    final libraryName = uri.substring('dart:'.length);
    return libraryName.isEmpty || _identifier.hasMatch(libraryName);
  }
  if (uri.startsWith('package:')) {
    final packagePath = uri.substring('package:'.length);
    if (packagePath.isEmpty) return true;
    final segments = packagePath.split('/');
    if (!_identifier.hasMatch(segments.first)) return false;
    final pathSegments = segments.skip(1).toList();
    if (pathSegments.isNotEmpty && pathSegments.last.isEmpty) {
      pathSegments.removeLast();
    }
    return pathSegments.every(
      (segment) =>
          segment != '.' && segment != '..' && _pathSegment.hasMatch(segment),
    );
  }
  return false;
}

/// Replaces the parts of [dartSource] that DartPad cannot process with spaces.
///
/// Unsafe directives (see [isSafeDirective]) are blanked out, as is the
/// `@docImport` tag of any documentation import with an unsafe URI. Line
/// breaks are kept, so offsets, lines, and columns are unchanged.
///
/// The result is parsed again until it is stable. If it does not become
/// stable, the whole source is blanked out.
String sanitizeSourceForAnalysis(String dartSource) {
  var sanitized = dartSource;
  for (var round = 0; round < _maxSanitizeRounds; round++) {
    final ranges = _unsafeRanges(_parse(sanitized));
    if (ranges.isEmpty) return sanitized;
    sanitized = _blankRanges(sanitized, ranges);
  }
  return _blankRanges(sanitized, [(0, sanitized.length)]);
}

extension ImportDirectiveExtension on ImportDirective {
  /// Whether this import has a `dart:` URI.
  bool get dartImport => uri.stringValue?.startsWith('dart:') ?? false;

  /// Whether this import has a `package:` URI.
  bool get packageImport => uri.stringValue?.startsWith('package:') ?? false;

  /// The library or package name of this import, or an empty string if the URI
  /// has no path segments.
  String get packageName {
    final uriValue = uri.stringValue;
    if (uriValue == null) return '';
    final parsedUri = Uri.tryParse(uriValue);
    if (parsedUri == null || parsedUri.pathSegments.isEmpty) return '';
    return parsedUri.pathSegments.first;
  }
}

const int _maxSanitizeRounds = 4;

final RegExp _identifier = RegExp(r'^[a-zA-Z0-9_]+$');
final RegExp _pathSegment = RegExp(r'^[a-zA-Z0-9_.\-]+$');

CompilationUnit _parse(String dartSource) =>
    parseString(content: dartSource, throwIfDiagnostics: false).unit;

/// Whether the tokens of [directive] after its metadata contain a string.
bool _hasStringLiteral(Directive directive) {
  final end = directive.endToken;
  Token? token = directive.firstTokenAfterCommentAndMetadata;
  while (token != null && !token.isEof) {
    if (token.type == TokenType.STRING) return true;
    if (identical(token, end)) break;
    token = token.next;
  }
  return false;
}

/// The source ranges in [unit] that must be blanked out before analysis.
List<(int, int)> _unsafeRanges(CompilationUnit unit) {
  final collector = _DocImportCollector();
  unit.accept(collector);
  return [
    for (final directive in unit.directives)
      if (!isSafeDirective(directive)) (directive.offset, directive.end),
    for (final docImport in collector.docImports)
      if (!isSafeDirective(docImport.import))
        (docImport.offset, docImport.offset + _docImportTag.length),
  ];
}

const String _docImportTag = '@docImport';

/// Replaces the code units in [ranges] with spaces, except line breaks.
String _blankRanges(String source, List<(int, int)> ranges) {
  final codeUnits = source.codeUnits.toList();
  for (final (start, end) in ranges) {
    for (var i = start; i < end && i < codeUnits.length; i++) {
      if (i < 0) continue;
      final codeUnit = codeUnits[i];
      if (codeUnit != _lineFeed && codeUnit != _carriageReturn) {
        codeUnits[i] = _space;
      }
    }
  }
  return String.fromCharCodes(codeUnits);
}

const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;

/// Collects the documentation imports of every comment in a unit.
final class _DocImportCollector extends RecursiveAstVisitor<void> {
  final List<DocImport> docImports = [];

  @override
  void visitComment(Comment node) {
    docImports.addAll(node.docImports);
    super.visitComment(node);
  }
}
