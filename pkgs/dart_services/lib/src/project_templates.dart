// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dartpad_shared/util.dart' show isSupportedFlutterPackage;
import 'package:path/path.dart' as path;

export 'package:dartpad_shared/util.dart'
    show isFlutterWebImport, supportedFlutterPackages, usesFlutterWeb;

/// Sets of project template directory paths.
class ProjectTemplates {
  ProjectTemplates._({
    required this.dartPath,
    required this.flutterPath,
    required this.summaryFilePath,
  });

  factory ProjectTemplates() {
    final basePath = _baseTemplateProject();
    final summaryFilePath = path.join('artifacts', 'flutter_web.dill');
    return ProjectTemplates._(
      dartPath: path.join(basePath, 'dart_project'),
      flutterPath: path.join(basePath, 'flutter_project'),
      summaryFilePath: summaryFilePath,
    );
  }

  /// The path to the plain Dart project template path.
  final String dartPath;

  /// The path to the Flutter project template path.
  final String flutterPath;

  /// The path to summary files.
  final String summaryFilePath;

  static ProjectTemplates projectTemplates = ProjectTemplates();

  static String _baseTemplateProject() =>
      path.join(Directory.current.path, 'project_templates');
}

/// The set of basic Dart (non-Flutter) packages which can be directly imported
/// into a script.
const Set<String> supportedBasicDartPackages = {
  'async',
  'basics',
  'bloc',
  'characters',
  'collection',
  'convert',
  'cross_file',
  'dartz',
  'english_words',
  'equatable',
  'fast_immutable_collections',
  'http',
  'intl',
  'lints',
  'matcher',
  'meta',
  'path',
  'petitparser',
  'quiver',
  'riverpod',
  'rohd',
  'rohd_vf',
  'rxdart',
  'signals',
  'stack_trace',
  'timezone',
  'typed_data',
  'vector_math',
  'web',
  'yaml',
  'yaml_edit',
};

/// The set of all packages whose support in DartPad is deprecated.
const Set<String> _deprecatedPackages = {};

/// A set of all allowed `dart:` libraries, includes
/// all libraries from "Core", some from "Web", and none from "VM".
const Set<String> _allowedCoreLibraries = {
  'async',
  'collection',
  'convert',
  'core',
  'developer',
  'math',
  'typed_data',
  'js_interop',
  'js_interop_unsafe',
  'ui',
};

/// Whether [libraryName] is the name of a supported `dart:` core library.
bool isSupportedCoreLibrary(String libraryName) =>
    _allowedCoreLibraries.contains(libraryName);

/// The core set of Firebase packages.
const Set<String> firebasePackages = {
  'cloud_firestore',
  'firebase_auth',
  'firebase_core',
};

bool isFirebasePackage(String packageName) {
  if (firebasePackages.contains(packageName)) return true;

  if (packageName.startsWith('firebase_')) return true;

  return false;
}

bool isSupportedDartPackage(String package) =>
    supportedBasicDartPackages.contains(package);

bool isSupportedPackage(String package) =>
    isSupportedFlutterPackage(package) || isSupportedDartPackage(package);

/// If the specified [package] is deprecated in DartPad and
/// slated to be removed in a future update.
bool isDeprecatedPackage(String package) =>
    _deprecatedPackages.contains(package);
