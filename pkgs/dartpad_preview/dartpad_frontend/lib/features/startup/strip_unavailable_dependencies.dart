// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'project_loader.dart';

/// Removes unavailable dependencies and appends their original source as
/// comments marked `stripped by DartPad` at the end of each pubspec.
///
/// Path dependencies must point to a package supplied by the same source.
/// Git dependencies cannot be fetched by the browser runtime. Changes happen
/// once during import, so later user edits remain under the user's control.
/// Dependencies requiring unsupported alias edits are preserved with a warning.
void stripUnavailableDependencies(Project project) {
  for (final file in project.files.toList()) {
    final fileName = basenameWorkspacePath(file.path);
    if (fileName != 'pubspec.yaml' && fileName != 'pubspec_overrides.yaml') {
      continue;
    }
    _stripUnavailableDependenciesInFile(project, file);
  }
}

/// Prepares one pubspec, keeping dependencies whose alias edits are unsupported.
void _stripUnavailableDependenciesInFile(Project project, ProjectFile file) {
  final String pubspecSource;
  final YamlEditor pubspecEditor;
  try {
    pubspecSource = utf8.decode(file.bytes);
    pubspecEditor = YamlEditor(pubspecSource);
  } on FormatException {
    // Leave invalid UTF-8 or YAML unchanged for the normal validation path.
    return;
  }
  // Keep this snapshot: its spans refer to pubspecSource, even after editor
  // mutations. Reparsing sections from the edited document would shift them.
  final pubspecNode = pubspecEditor.parseAt([]);
  if (pubspecNode is! YamlMap) {
    return;
  }

  final strippedDependencyComments = <String>[];
  final warnings = <String>[];
  final lineEnding = pubspecSource.contains('\r\n') ? '\r\n' : '\n';
  final packageDirectory = parentWorkspacePath(file.path);
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
      try {
        // yaml_edit refuses edits to aliases and anchors before changing the
        // source. Try removal before slicing spans, which may point outside
        // this entry, and keep only this dependency if the edit is unsupported.
        pubspecEditor.remove([sectionName, dependencyName]);
      } on AliasException {
        warnings.add(
          'Dependency "$dependencyName" in ${file.path} ($sectionName) was left unchanged: '
          'editing YAML aliases is not supported.',
        );
        continue;
      }
      final entryText = pubspecSource
          .substring(
            dependencyNameNode.span.start.offset,
            dependencyNode.span.end.offset,
          )
          .trimRight();
      strippedDependencyComments.add(_commentOutEntry(entryText, lineEnding));
      warnings.add(
        'Dependency "$dependencyName" in ${file.path} ($sectionName) $unavailableReason and was not loaded.',
      );
    }
  }
  if (strippedDependencyComments.isNotEmpty) {
    final updatedPubspecSource = '$pubspecEditor$lineEnding${strippedDependencyComments.join(lineEnding)}$lineEnding';
    project.writeFile(file.path, Uint8List.fromList(utf8.encode(updatedPubspecSource)));
  }
  for (final warning in warnings) {
    project.addImportWarning(warning);
  }
}

String _commentOutEntry(String entryText, String lineEnding) {
  final entryLines = entryText.split(RegExp(r'\r\n|\r|\n'));
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
