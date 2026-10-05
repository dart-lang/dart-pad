// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'project_loader.dart';

/// Comments out dependencies that cannot be loaded from an imported project.
///
/// Path dependencies must point to a package supplied by the same source.
/// Git dependencies cannot be fetched by the browser runtime. Changes happen
/// once during import, so later user edits remain under the user's control.
void stripUnavailableDependencies(Project project) {
  for (final file in project.files.toList()) {
    final fileName = basenameWorkspacePath(file.path);
    if (fileName != 'pubspec.yaml' && fileName != 'pubspec_overrides.yaml') {
      continue;
    }
    // Parse each pubspec and keep its original source for the stripped dependency comments.
    final String pubspecSource;
    final YamlEditor pubspecEditor;
    try {
      pubspecSource = utf8.decode(file.bytes);
      pubspecEditor = YamlEditor(pubspecSource);
    } on FormatException {
      continue;
    }
    final pubspecNode = pubspecEditor.parseAt([]);
    if (pubspecNode is! YamlMap) {
      continue;
    }

    final strippedDependencyComments = <String>[];
    final lineEnding = pubspecSource.contains('\r\n') ? '\r\n' : '\n';
    final packageDirectory = parentWorkspacePath(file.path);
    // Check individual dependency entries, remove unavailable ones, and record warnings.
    for (final sectionName in ['dependencies', 'dev_dependencies', 'dependency_overrides']) {
      final dependencySection = pubspecNode.nodes[sectionName];
      if (dependencySection is! YamlMap) {
        continue;
      }
      for (final dependencyEntry in dependencySection.nodes.entries) {
        final dependencyNameNode = dependencyEntry.key as YamlNode;
        final dependencyName = dependencyNameNode.value;
        final dependencyNode = dependencyEntry.value;
        if (dependencyName is! String || dependencyNode is! YamlMap) {
          continue;
        }
        final unavailableReason = _unavailableDependencyReason(project, packageDirectory, dependencyNode);
        if (unavailableReason == null) {
          continue;
        }
        final entryText = pubspecSource
            .substring(
              dependencyNameNode.span.start.offset,
              dependencyNode.span.end.offset,
            )
            .trimRight();
        strippedDependencyComments.add(_commentOutEntry(entryText, lineEnding));
        pubspecEditor.remove([sectionName, dependencyName]);
        project.addImportWarning(
          'Dependency "$dependencyName" in ${file.path} ($sectionName) $unavailableReason and was not loaded.',
        );
      }
    }
    if (strippedDependencyComments.isEmpty) {
      continue;
    }
    // Append the removed entries as comments and write the edited YAML back to the project.
    final updatedPubspecSource = '$pubspecEditor$lineEnding${strippedDependencyComments.join(lineEnding)}$lineEnding';
    project.writeFile(file.path, Uint8List.fromList(utf8.encode(updatedPubspecSource)));
  }
}

String _commentOutEntry(String entryText, String lineEnding) {
  final entryLines = entryText.split(lineEnding);
  final commentedLines = [for (final line in entryLines) line.isEmpty ? '' : '# $line'];
  if (commentedLines.first.isNotEmpty) {
    commentedLines[0] += ' # stripped by DartPad';
  }
  return commentedLines.join(lineEnding);
}

String? _unavailableDependencyReason(Project project, String packageDirectory, YamlMap dependencyNode) {
  if (dependencyNode.containsKey('git')) {
    return 'uses Git, which is unavailable in the browser workspace';
  }
  final dependencyPath = dependencyNode['path'];
  if (dependencyPath is! String) {
    return null;
  }
  final dependencyDirectory = joinWorkspacePath(packageDirectory, dependencyPath);
  final isAbsolutePath = workspacePath.isAbsolute(dependencyPath);
  if (isAbsolutePath || !isWithinWorkspaceFolder(dependencyDirectory, '')) {
    return 'uses ${isAbsolutePath ? 'absolute' : 'relative'} path "$dependencyPath", which is outside the imported workspace';
  }
  final dependencyPubspecPath = joinWorkspacePath(dependencyDirectory, 'pubspec.yaml');
  if (!project.containsFile(dependencyPubspecPath)) {
    return 'uses relative path "$dependencyPath", whose target package is not included in the imported workspace';
  }
  return null;
}
