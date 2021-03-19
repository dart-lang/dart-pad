// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;

/// Support for handling Flutter web snippets.
class FlutterWebManager {
  static final Directory flutterTemplateProject = Directory(path.join(
      Directory.current.path, 'project_templates', 'flutter_project'));

  static final Directory dartTemplateProject = Directory(
      path.join(Directory.current.path, 'project_templates', 'dart_project'));

  FlutterWebManager();

  String get summaryFilePath {
    return path.join('artifacts', 'flutter_web.dill');
  }

  static const Set<String> _flutterWebImportPrefixes = {
    'package:flutter',
    'dart:ui',
  };

  /// A set of all allowed `dart:` imports. Currently includes non-VM libraries
  /// listed as the [doc](https://api.dart.dev/stable/index.html) categories.
  static const Set<String> _allowedDartImports = {
    'dart:async',
    'dart:collection',
    'dart:convert',
    'dart:core',
    'dart:developer',
    'dart:math',
    'dart:typed_data',
    'dart:html',
    'dart:indexed_db',
    'dart:js',
    'dart:js_util',
    'dart:svg',
    'dart:web_audio',
    'dart:web_gl',
    'dart:web_sql',
    'dart:ui',
  };

  bool usesFlutterWeb(Set<String> imports) {
    return imports.any((String import) {
      return _flutterWebImportPrefixes.any(
        (String prefix) => import.startsWith(prefix),
      );
    });
  }

  bool hasUnsupportedImport(Set<String> imports) {
    return getUnsupportedImport(imports) != null;
  }

  String getUnsupportedImport(Set<String> imports) {
    for (final import in imports) {
      // All non-VM dart: imports are ok
      if (import.startsWith('dart:') && _allowedDartImports.contains(import)) {
        continue;
      }

      // Currently we only allow flutter web imports.
      if (import.startsWith('package:')) {
        if (_flutterWebImportPrefixes
            .any((String prefix) => import.startsWith(prefix))) {
          continue;
        }

        return import;
      }

      // Don't allow file imports.
      return import;
    }

    return null;
  }
}
