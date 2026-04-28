// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Entrypoint for uses of package:analyzer.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

export 'package:analyzer/dart/ast/ast.dart' show ImportDirective;

/// Extract all imports from [dartSource] source code.
List<ImportDirective> getAllImportsFor(String dartSource) {
  final unit = parseString(content: dartSource, throwIfDiagnostics: false).unit;
  return unit.directives.whereType<ImportDirective>().toList();
}

extension ImportDirectiveExtension on ImportDirective {
  bool get dartImport => Uri.parse(uri.stringValue!).scheme == 'dart';

  bool get packageImport => Uri.parse(uri.stringValue!).scheme == 'package';

  String get packageName => Uri.parse(uri.stringValue!).pathSegments.first;
}
