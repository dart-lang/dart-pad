// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;

/// Sets of project template directory paths.
class ProjectTemplates {
  ProjectTemplates._({
    required this.dartPath,
    required this.flutterPath,
    required this.firebasePath,
    required this.summaryFilePath,
  });

  factory ProjectTemplates({required bool nullSafety}) {
    final basePath = _baseTemplateProject(nullSafety: nullSafety);
    final summaryFilePath = path.join(
      'artifacts',
      nullSafety ? 'null-safe' : 'null-unsafe',
      'flutter_web.dill',
    );
    return ProjectTemplates._(
      dartPath: path.join(basePath, 'dart_project'),
      flutterPath: path.join(basePath, 'flutter_project'),
      firebasePath: path.join(basePath, 'firebase_project'),
      summaryFilePath: summaryFilePath,
    );
  }

  /// The path to the plain Dart project template path.
  final String dartPath;

  /// The path to the Flutter (without Firebase) project template path.
  final String flutterPath;

  /// The path to the Firebase (with Flutter) project template path.
  final String firebasePath;

  /// The path to summary files.
  final String summaryFilePath;

  static ProjectTemplates nullUnsafe = ProjectTemplates(nullSafety: false);
  static ProjectTemplates nullSafe = ProjectTemplates(nullSafety: true);

  static String _baseTemplateProject({required bool nullSafety}) => path.join(
        Directory.current.path,
        'project_templates',
        nullSafety ? 'null-safe' : 'null-unsafe',
      );
}

/// The set of Firebase packages which can be registered in the generated
/// registrant file. Theoretically this should be _all_ plugins, but there
/// are bugs. See https://github.com/dart-lang/dart-pad/issues/2033 and
/// https://github.com/FirebaseExtended/flutterfire/issues/3962.
const Set<String> registerableFirebasePackages = {
  'cloud_functions',
  'firebase',
  'firebase_auth',
  'firebase_core',
  'firebase_storage',
};

/// The set of Firebase packages which indicate that Firebase is being used.
const Set<String> firebasePackages = {
  'cloud_firestore',
  'firebase_analytics',
  'firebase_database',
  'firebase_messaging',
  ...registerableFirebasePackages,
};

/// The set of packages which indicate that Flutter Web is being used.
const Set<String> supportedFlutterPackages = {
  'flutter_bloc',
  'flutter_lints',
  'flutter_riverpod',
  'url_launcher',
};

/// The set of packages which indicate that Flutter Web is being used.
const Set<String> _packagesIndicatingFlutter = {
  'flutter',
  'flutter_test',
  ...supportedFlutterPackages,
  ...firebasePackages,
};

/// The set of basic Dart (non-Flutter) packages which can be directly imported
/// into a script.
const Set<String> supportedBasicDartPackages = {
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

/// Returns whether [imports] denote use of Flutter Web.
bool usesFlutterWeb(Iterable<ImportDirective> imports) {
  return imports.any((import) {
    final uriString = import.uri.stringValue;
    if (uriString == null) return false;
    if (uriString == 'dart:ui') return true;

    final uri = Uri.tryParse(uriString);
    if (uri == null) return false;
    if (uri.scheme != 'package') return false;
    if (uri.pathSegments.isEmpty) return false;
    final package = uri.pathSegments.first;
    return _packagesIndicatingFlutter.contains(package);
  });
}

/// Returns whether [imports] denote use of Firebase.
bool usesFirebase(Iterable<ImportDirective> imports) {
  return imports.any((import) {
    final uriString = import.uri.stringValue;
    if (uriString == null) return false;

    final uri = Uri.tryParse(uriString);
    if (uri == null) return false;
    if (uri.scheme != 'package') return false;
    if (uri.pathSegments.isEmpty) return false;
    final package = uri.pathSegments.first;
    return firebasePackages.contains(package);
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
    _packagesIndicatingFlutter.contains(package) ||
    supportedBasicDartPackages.contains(package);
