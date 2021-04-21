// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

List<ImportDirective> getAllImportsFor(String dartSource) {
  if (dartSource == null) return [];

  final unit = parseString(content: dartSource, throwIfDiagnostics: false).unit;
  return unit.directives.whereType<ImportDirective>().toList();
}

extension ImportIterableExtensions on Iterable<ImportDirective> {
  /// Returns the names of packages that are referenced in this collection.
  /// These package names are sanitized defensively.
  Iterable<String> filterSafePackages() {
    return where((import) => !import.uri.stringValue.startsWith('package:../'))
        .map((import) => Uri.parse(import.uri.stringValue))
        .where((uri) => uri.scheme == 'package' && uri.pathSegments.isNotEmpty)
        .map((uri) => uri.pathSegments.first);
  }
}
