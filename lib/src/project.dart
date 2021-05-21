// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;

Directory flutterTemplateProject(bool nullSafety) => Directory(path.join(
      Directory.current.path,
      'project_templates',
      nullSafety ? 'null-safe' : 'null-unsafe',
      'flutter_project',
    ));

Directory dartTemplateProject(bool nullSafety) => Directory(path.join(
      Directory.current.path,
      'project_templates',
      nullSafety ? 'null-safe' : 'null-unsafe',
      'dart_project',
    ));

String summaryFilePath(bool nullSafety) {
  return path.join(
    'artifacts',
    nullSafety ? 'null-safe' : 'null-unsafe',
    'flutter_web.dill',
  );
}

const Set<String> _flutterImportPrefixes = {
  'package:cloud_firestore/',
  'package:firebase/',
  'package:firebase_auth/',
  'package:firebase_core/',
  'package:flutter/',
  'package:flutter_test/',
  'package:pedantic/',
  'dart:ui',
};

/// A set of all allowed `dart:` imports. Currently includes non-VM libraries
/// listed as the [doc](https://api.dart.dev/stable/index.html) categories.
const Set<String> _allowedDartImports = {
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

bool usesFlutterWeb(Iterable<ImportDirective> imports) {
  return imports.any((import) {
    return _flutterImportPrefixes
        .any((String prefix) => import.uri.stringValue.startsWith(prefix));
  });
}

List<ImportDirective> getUnsupportedImports(List<ImportDirective> imports) {
  return imports.where((import) {
    final uri = import.uri.stringValue;
    // All non-VM 'dart:' imports are ok.
    if (uri.startsWith('dart:')) {
      return !_allowedDartImports.contains(uri);
    }

    // Currently we only allow flutter web imports.
    if (uri.startsWith('package:')) {
      return !_flutterImportPrefixes
          .any((String prefix) => uri.startsWith(prefix));
    }

    // Don't allow file imports.
    return true;
  }).toList();
}
