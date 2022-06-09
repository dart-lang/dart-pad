// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'project.dart' as project;

/// Extract all imports from [dartSource] source code.
List<ImportDirective> getAllImportsFor(String? dartSource) {
  if (dartSource == null) return [];

  final unit = parseString(content: dartSource, throwIfDiagnostics: false).unit;
  return unit.directives.whereType<ImportDirective>().toList();
}

/// Takes a map {"filename":"sourcecode"..."filenameN":"sourcecodeN"}
/// of source files and extracts the imports from each file's sourcecode and
/// returns an overall list of all imports across all files in the set.
List<ImportDirective> getAllImportsForFiles(Map<String, String> files) {
  return [
    for (final sourcecode in files.values) ...getAllImportsFor(sourcecode)
  ];
}

/// Flutter packages which do not have version numbers in pubspec.lock.
const _flutterPackages = [
  'flutter',
  'flutter_test',
  'flutter_web_plugins',
  'sky_engine',
];

/// This is expensive to calculate; they require reading from disk.
/// None of them changes during execution.
final Map<String, String> _nullSafePackageVersions =
    packageVersionsFromPubspecLock(
        project.ProjectTemplates.projectTemplates.firebasePath);

/// Returns a mapping of Pub package name to package version.
Map<String, String> getPackageVersions() => _nullSafePackageVersions;

/// Returns a mapping of Pub package name to package version, retrieving data
/// from the project template's `pubspec.lock` file.
Map<String, String> packageVersionsFromPubspecLock(String templatePath) {
  final pubspecLockPath = File(path.join(templatePath, 'pubspec.lock'));
  final pubspecLock = loadYamlDocument(pubspecLockPath.readAsStringSync());
  final pubSpecLockContents = pubspecLock.contents as YamlMap;
  final packages = pubSpecLockContents['packages'] as YamlMap;
  final packageVersions = <String, String>{};

  packages.forEach((nameKey, packageValue) {
    final name = nameKey as String;
    if (_flutterPackages.contains(name)) {
      return;
    }
    final package = packageValue as YamlMap;
    final source = package['source'];
    if (source is! String || source != 'hosted') {
      // `name` is not hosted. Might be a local or git dependency.
      return;
    }
    final version = package['version'];
    if (version is String) {
      packageVersions[name] = version;
    } else {
      throw StateError(
          '$name does not have a well-formatted version: $version');
    }
  });

  return packageVersions;
}

extension ImportIterableExtensions on Iterable<ImportDirective> {
  /// Returns the names of packages that are referenced in this collection.
  /// These package names are sanitized defensively.
  Iterable<String> filterSafePackages() {
    return where((import) => !import.uri.stringValue!.startsWith('package:../'))
        .map((import) => Uri.parse(import.uri.stringValue!))
        .where((uri) => uri.scheme == 'package' && uri.pathSegments.isNotEmpty)
        .map((uri) => uri.pathSegments.first);
  }
}
