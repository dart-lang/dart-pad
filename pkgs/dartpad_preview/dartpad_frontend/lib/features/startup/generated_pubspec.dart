// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'project_loader.dart';

/// Generates a root pubspec for a collection of standalone Dart files.
///
/// Package imports and exports become dependencies. Flutter is represented as
/// an SDK dependency and enables the bundled Material icons.
ProjectFile generatePubspec(Iterable<ProjectFile> files) {
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
    if (package.isNotEmpty && package != 'app') {
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

  final sortedDependencies = dependencies.toList()..sort();
  final pubspec = StringBuffer('''
name: app
publish_to: none

environment:
  sdk: ^3.12.0
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
