// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;

Directory flutterTemplateProject(bool nullSafety) => Directory(path.join(
      _baseTemplateProject(nullSafety),
      'flutter_project',
    ));

Directory dartTemplateProject(bool nullSafety) => Directory(path.join(
      _baseTemplateProject(nullSafety),
      'dart_project',
    ));

String _baseTemplateProject(bool nullSafety) => path.join(
      Directory.current.path,
      'project_templates',
      nullSafety ? 'null-safe' : 'null-unsafe',
    );

String summaryFilePath(bool nullSafety) {
  return path.join(
    'artifacts',
    nullSafety ? 'null-safe' : 'null-unsafe',
    'flutter_web.dill',
  );
}

/// The set of packages which indicate that Flutter Web is being used.
const Set<String> _flutterPackages = {
  'cloud_firestore',
  'firebase',
  'firebase_auth',
  'firebase_core',
  'firebase_database',
  'flutter',
  'flutter_bloc',
  'flutter_riverpod',
  'flutter_test',
};

/// The set of non-Flutter packages which can be directly imported into a
/// script.
const Set<String> supportedNonFlutterPackages = {
  'bloc',
  'characters',
  'collection',
  'google_fonts',
  'http',
  'intl',
  'js',
  'lints',
  'meta',
  'path',
  'pedantic',
  'provider',
  'riverpod',
  'url_launcher',
  'vector_math',
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
    final uriString = import.uri.stringValue;
    if (uriString == 'dart:ui') return true;

    final uri = Uri.tryParse(import.uri.stringValue!);
    if (uri == null) return false;
    if (uri.scheme != 'package') return false;
    if (uri.pathSegments.isEmpty) return false;
    final package = uri.pathSegments.first;
    return _flutterPackages.contains(package);
  });
}

List<ImportDirective> getUnsupportedImports(List<ImportDirective> imports) {
  return imports.where((import) {
    final uriString = import.uri.stringValue;
    if (uriString == null) {
      return false;
    }
    // All non-VM 'dart:' imports are ok.
    if (uriString.startsWith('dart:')) {
      return !_allowedDartImports.contains(uriString);
    }

    final uri = Uri.tryParse(uriString);
    if (uri == null) return false;

    // We allow a specific set of package imports.
    if (uri.scheme == 'package') {
      if (uri.pathSegments.isEmpty) return true;
      final package = uri.pathSegments.first;
      return !isSupportedPackage(package);
    }

    // Don't allow file imports.
    return true;
  }).toList();
}

bool isSupportedPackage(String package) =>
    _flutterPackages.contains(package) ||
    supportedNonFlutterPackages.contains(package);
