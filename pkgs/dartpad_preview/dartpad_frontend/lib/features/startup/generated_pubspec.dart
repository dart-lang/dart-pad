// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'project_loader.dart';

/// Infers dependencies from package imports and exports in standalone Dart files.
Set<String> inferPackageDependencies(Iterable<ProjectFile> files) {
  final dependencies = <String>{};

  void addDependency(String? uriString) {
    if (uriString == null) {
      return;
    }
    final parsed = Uri.tryParse(uriString);
    if (parsed?.scheme != 'package' || parsed!.pathSegments.isEmpty) {
      return;
    }
    final package = parsed.pathSegments.first;
    if (package.isNotEmpty) {
      dependencies.add(package);
    }
  }

  for (final file in files) {
    if (!file.path.endsWith('.dart')) {
      continue;
    }
    final unit = parseString(
      content: utf8.decode(file.bytes, allowMalformed: true),
      throwIfDiagnostics: false,
    ).unit;
    for (final directive in unit.directives) {
      if (directive is NamespaceDirective) {
        addDependency(directive.uri.stringValue);
        for (final config in directive.configurations) {
          addDependency(config.uri.stringValue);
        }
      }
    }
  }

  dependencies.remove('_');
  return dependencies;
}

/// Generates a root pubspec using the selected runtime's SDK constraint.
///
/// Flutter is represented as an SDK dependency and enables the bundled Material
/// icons. Dependency inference is separate so startup can select the SDK first.
ProjectFile generatePubspec(Iterable<String> dependencies, {required String sdkConstraint}) {
  final sortedDependencies = dependencies.toList()..sort();
  final pubspec = StringBuffer('''
name: _
publish_to: none

environment:
  sdk: $sdkConstraint
''');
  if (sortedDependencies.isNotEmpty) {
    pubspec.writeln('\ndependencies:');
    for (final dependency in sortedDependencies) {
      if (dependency == 'flutter') {
        pubspec.writeln('  flutter:\n    sdk: flutter');
      } else {
        pubspec.writeln('  $dependency: any');
      }
    }
  }
  if (dependencies.contains('flutter')) {
    pubspec.write('''

flutter:
  uses-material-design: true
''');
  }

  return ProjectFile(
    path: 'pubspec.yaml',
    bytes: Uint8List.fromList(utf8.encode(pubspec.toString())),
  );
}

/// Uses the bundled SDK's version, including prereleases of that version.
String generatedSdkConstraint(String dartVersion) {
  // Manifest versions can include build descriptions or an `-edge` suffix.
  final match = RegExp(r'^(\d+\.\d+\.\d+)(?=$|[-+\s])').firstMatch(dartVersion.trim());
  if (match == null) {
    throw FormatException('Invalid Dart SDK version', dartVersion);
  }
  return '^${match.group(1)}-0';
}
