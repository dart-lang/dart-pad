// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import 'utils.dart';

/// Sets of project template directory paths.
class ProjectTemplates {
  ProjectTemplates._({
    required this.dartPath,
    required this.flutterPath,
    required this.summaryFilePath,
  });

  factory ProjectTemplates._factory() {
    final templatesDirectory = _templatesDirectoryPath();
    return ProjectTemplates._(
      dartPath: path.join(templatesDirectory, 'dart_project'),
      flutterPath: path.join(templatesDirectory, 'flutter_project'),
      summaryFilePath: path.join('artifacts', 'flutter_web.dill'),
    );
  }

  /// The path to the plain Dart project template path.
  final String dartPath;

  /// The path to the Flutter project template path.
  final String flutterPath;

  /// The path to summary files.
  final String summaryFilePath;

  static ProjectTemplates instance = ProjectTemplates._factory();

  static String _templatesDirectoryPath() {
    final dir = path.join(
      Directory.current.path,
      '..',
      'dart_services',
      'project_templates',
    );

    return normalizeAbsolutePath(dir);
  }
}

/// The set of supported Flutter-oriented packages.
const Set<String> supportedFlutterPackages = {
  'animated_to',
  'animations',
  'creator',
  'flame',
  'flame_fire_atlas',
  'flame_forge2d',
  'flame_splash_screen',
  'flame_tiled',
  'flutter_adaptive_scaffold',
  'flutter_bloc',
  'flutter_hooks',
  'flutter_map',
  'flutter_markdown',
  'flutter_riverpod',
  'flutter_svg',
  'go_router',
  'google_fonts',
  'google_generative_ai',
  'hooks_riverpod',
  'mix',
  'provider',
  'shared_preferences',
  'url_launcher',
  'video_player',
};

/// The set of packages which indicate that Flutter Web is being used.
const Set<String> _packagesIndicatingFlutter = {
  'flutter',
  'flutter_test',
  ...supportedFlutterPackages,
};

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
  'dio',
  'dio_web_adapter',
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

/// The deprecated set of `dart:` libraries for web and JS.
///
/// To avoid duplicate diagnostics now that they are marked as deprecated,
/// importing them is temporarily allowed (but still discouraged).
const Set<String> _deprecatedCoreWebLibraries = {
  'html',
  'indexed_db',
  'js',
  'js_util',
  'svg',
  'web_audio',
  'web_gl',
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
  'js_interop',
  'js_interop_unsafe',
  'ui',
  ..._deprecatedCoreWebLibraries,
};

/// Whether [libraryName] is the name of a supported `dart:` core library.
bool isSupportedCoreLibrary(String libraryName) =>
    _allowedCoreLibraries.contains(libraryName);

/// Whether [imports] denote use of Flutter Web.
bool usesFlutterWeb(Iterable<ImportDirective> imports) =>
    imports.any((import) => isFlutterWebImport(import.uri.stringValue));

/// Whether the [importString] represents an import that denotes use of Flutter
/// Web.
@visibleForTesting
bool isFlutterWebImport(String? importString) {
  if (importString == null) return false;
  if (importString == 'dart:ui') return true;

  final packageName = _packageNameFromPackageUri(importString);
  return packageName != null &&
      _packagesIndicatingFlutter.contains(packageName);
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

bool isSupportedFlutterPackage(String package) =>
    _packagesIndicatingFlutter.contains(package);

bool isSupportedDartPackage(String package) =>
    supportedBasicDartPackages.contains(package);

bool isSupportedPackage(String package) =>
    isSupportedFlutterPackage(package) || isSupportedDartPackage(package);

/// If the specified [package] is deprecated in DartPad and
/// slated to be removed in a future update.
bool isDeprecatedPackage(String package) =>
    _deprecatedPackages.contains(package);
