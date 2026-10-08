// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Entrypoint for uses of package:analyzer.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

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
List<Directive> getAllDirectivesFor(String dartSource) {
  final unit = parseString(content: dartSource, throwIfDiagnostics: false).unit;
  return unit.directives.toList();
}

/// Replaces any directive in [dartSource] that is not a [LibraryDirective] or
/// a valid `dart:` / `package:` [ImportDirective] with spaces of the same
/// length (preserving line breaks) so character offsets, lines, and columns
/// remain identical.
String sanitizeSourceForAnalysis(String dartSource) {
  final directives = getAllDirectivesFor(dartSource);
  final unsupportedDirectives = directives.where((directive) {
    if (directive is LibraryDirective) return false;
    if (directive is ImportDirective) {
      return !directive.dartImport && !directive.packageImport;
    }
    return true;
  }).toList();

  if (unsupportedDirectives.isEmpty) {
    return dartSource;
  }

  final buffer = StringBuffer();
  var lastEnd = 0;
  for (final directive in unsupportedDirectives) {
    final start = directive.offset;
    final end = directive.end;
    if (start > lastEnd) {
      buffer.write(dartSource.substring(lastEnd, start));
    }
    for (var i = start; i < end; i++) {
      final char = dartSource[i];
      buffer.write(char == '\n' || char == '\r' ? char : ' ');
    }
    lastEnd = end;
  }
  if (lastEnd < dartSource.length) {
    buffer.write(dartSource.substring(lastEnd));
  }
  return buffer.toString();
}

final RegExp _validIdentifier = RegExp(r'^[a-zA-Z0-9_]+$');
final RegExp _validPathSegment = RegExp(r'^[a-zA-Z0-9_.\-]+$');

extension ImportDirectiveExtension on ImportDirective {
  /// Whether this is a valid `dart:<library>` import.
  bool get dartImport {
    if (configurations.isNotEmpty) return false;
    final uriValue = uri.stringValue;
    if (uriValue == null || !uriValue.startsWith('dart:')) {
      return false;
    }
    final libraryName = uriValue.substring('dart:'.length);
    return _validIdentifier.hasMatch(libraryName);
  }

  /// Whether this is a valid `package:` import.
  bool get packageImport {
    if (configurations.isNotEmpty) return false;
    final uriValue = uri.stringValue;
    if (uriValue == null || !uriValue.startsWith('package:')) {
      return false;
    }
    final packagePath = uriValue.substring('package:'.length);
    final rawSegments = packagePath.split('/');
    if (rawSegments.isEmpty || !_validIdentifier.hasMatch(rawSegments.first)) {
      return false;
    }
    if (!rawSegments.every(
      (segment) =>
          segment.isNotEmpty &&
          segment != '.' &&
          segment != '..' &&
          _validPathSegment.hasMatch(segment),
    )) {
      return false;
    }
    final parsedUri = Uri.tryParse(uriValue);
    return parsedUri != null &&
        parsedUri.scheme == 'package' &&
        !parsedUri.hasAuthority &&
        !parsedUri.hasQuery &&
        !parsedUri.hasFragment;
  }

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
