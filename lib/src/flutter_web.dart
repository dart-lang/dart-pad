// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;

import 'sdk_manager.dart';

/// Handle provisioning package:flutter_web and related work.
class FlutterWebManager {
  final FlutterSdk flutterSdk;

  final Directory flutterTemplateProject = Directory(path.join(
      Directory.current.path, 'project_templates', 'flutter_project'));

  final Directory dartTemplateProject = Directory(
      path.join(Directory.current.path, 'project_templates', 'dart_project'));

  FlutterWebManager(this.flutterSdk);

  String get summaryFilePath {
    return path.join('artifacts', 'flutter_web.dill');
  }

  static final Set<String> _flutterWebImportPrefixes = <String>{
    'package:flutter',
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
      // All dart: imports are ok;
      if (import.startsWith('dart:')) {
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
