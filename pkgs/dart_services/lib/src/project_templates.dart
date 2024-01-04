// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Sets of project template directory paths.
class ProjectTemplates {
  ProjectTemplates._({
    required this.dartPath,
    required this.flutterPath,
    required this.firebasePath,
    required this.firebaseDeprecatedPath,
    required this.summaryFilePath,
  });

  factory ProjectTemplates() {
    final basePath = _baseTemplateProject();
    final summaryFilePath = path.join(
      'artifacts',
      'flutter_web.dill',
    );
    return ProjectTemplates._(
      dartPath: path.join(basePath, 'dart_project'),
      flutterPath: path.join(basePath, 'flutter_project'),
      firebasePath: path.join(basePath, 'firebase_project'),
      firebaseDeprecatedPath:
          path.join(basePath, 'firebase_deprecated_project'),
      summaryFilePath: summaryFilePath,
    );
  }

  /// The path to the plain Dart project template path.
  final String dartPath;

  /// The path to the Flutter (without Firebase) project template path.
  final String flutterPath;

  /// The path to the Firebase (with Flutter) project template path.
  final String firebasePath;

  /// The path to the deprecated Firebase (with Flutter) project template path.
  final String firebaseDeprecatedPath;

  /// The path to summary files.
  final String summaryFilePath;

  static ProjectTemplates projectTemplates = ProjectTemplates();

  static String _baseTemplateProject() =>
      path.join(Directory.current.path, 'project_templates');
}

/// The set of Firebase packages which are used in both deprecated Firebase
/// projects and "pure Dart" Flutterfire projects.
const Set<String> coreFirebasePackages = {
  'firebase_core',
};

/// The set of Firebase packages which can be registered in the generated
/// registrant file. Theoretically this should be _all_ plugins, but there
/// are bugs. See https://github.com/dart-lang/dart-pad/issues/2033 and
/// https://github.com/FirebaseExtended/flutterfire/issues/3962.
const Set<String> registerableFirebasePackages = {
  'cloud_firestore',
  'firebase_auth',
};

/// The set of Firebase packages which indicate that Firebase is being used.
const Set<String> firebasePackages = {
  ...coreFirebasePackages,
  ...registerableFirebasePackages,
};

/// The set of supported Flutter-oriented packages.
const Set<String> supportedFlutterPackages = {
  'animations',
  'creator',
  'firebase_analytics',
  'firebase_database',
  'firebase_messaging',
  'firebase_storage',
  'flame',
  'flame_fire_atlas',
  'flame_forge2d',
  'flame_splash_screen',
  'flame_tiled',
  'flutter_adaptive_scaffold',
  'flutter_bloc',
  'flutter_hooks',
  'flutter_lints',
  'flutter_map',
  'flutter_processing',
  'flutter_riverpod',
  'flutter_svg',
  'go_router',
  'google_fonts',
  'hooks_riverpod',
  'provider',
  'riverpod_navigator',
  'shared_preferences',
  'video_player',
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
  'basics',
  'bloc',
  'characters',
  'collection',
  'cross_file',
  'dartz',
  'english_words',
  'equatable',
  'fast_immutable_collections',
  'http',
  'intl',
  'js',
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
  'timezone',
  'tuple',
  'vector_math',
  'yaml',
  'yaml_edit',
};

/// The set of all packages whose support in DartPad is deprecated.
const Set<String> _deprecatedPackages = {
  'tuple',
};

/// The set of core web libraries whose support in
/// DartPad or Dart is deprecated.
const Set<String> _deprecatedCoreWebLibraries = {
  'js',
};

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

  'html', // TODO(parlough): Deprecate soon.
  'js_util', // TODO(parlough): Deprecate soon.
  'js_interop',
  'js_interop_unsafe',
  ..._deprecatedCoreWebLibraries,

  'ui',
};

/// Whether [libraryName] is the name of a supported `dart:` core library.
bool isSupportedCoreLibrary(String libraryName) =>
    _allowedCoreLibraries.contains(libraryName);

/// Whether [libraryName] is the name of a supported, but deprecated,
/// `dart:` core web library.
bool isDeprecatedCoreWebLibrary(String libraryName) =>
    _deprecatedCoreWebLibraries.contains(libraryName);

/// Whether [imports] denote use of Flutter Web.
bool usesFlutterWeb(Iterable<ImportDirective> imports) =>
    imports.any((import) => isFlutterWebImport(import.uri.stringValue));

/// Whether the [importString] represents an import
/// that denotes use of Flutter Web.
@visibleForTesting
bool isFlutterWebImport(String? importString) {
  if (importString == null) return false;
  if (importString == 'dart:ui') return true;

  final packageName = _packageNameFromPackageUri(importString);
  return packageName != null &&
      _packagesIndicatingFlutter.contains(packageName);
}

/// Returns whether [imports] denote use of Firebase.
bool usesFirebase(Iterable<ImportDirective> imports) =>
    imports.any((import) => isFirebaseImport(import.uri.stringValue));

/// Whether the [importString] represents an import
/// that denotes use of a Firebase package.
@visibleForTesting
bool isFirebaseImport(String? importString) {
  if (importString == null) return false;

  final packageName = _packageNameFromPackageUri(importString);
  return packageName != null && firebasePackages.contains(packageName);
}

/// If [uriString] represents a 'package:' URI, then returns the package name;
/// otherwise `null`.
String? _packageNameFromPackageUri(String uriString) {
  final uri = Uri.tryParse(uriString);
  if (uri == null) return null;
  if (uri.scheme != 'package') return null;
  if (uri.pathSegments.isEmpty) return null;
  return uri.pathSegments.first;
}

bool isSupportedPackage(String package) =>
    _packagesIndicatingFlutter.contains(package) ||
    supportedBasicDartPackages.contains(package);

/// If the specified [package] is deprecated in DartPad and
/// slated to be removed in a future update.
bool isDeprecatedPackage(String package) =>
    _deprecatedPackages.contains(package);
