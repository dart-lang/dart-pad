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
/// comments at the end of each pubspec, including their section and removal reason.
///
/// Path dependencies must point to a package supplied by the same source.
/// Git dependencies cannot be fetched by the browser runtime. Changes happen
/// once during import, so later user edits remain under the user's control.
/// Dependencies requiring unsupported alias edits are preserved with a warning.
void stripUnavailableDependencies(Project project) {
  final pubspecPaths = project.paths.where(
    (path) => const {'pubspec.yaml', 'pubspec_overrides.yaml'}.contains(basenameWorkspacePath(path)),
  );
  for (final path in pubspecPaths) {
    _stripUnavailableDependenciesInFile(project, path);
  }
}

/// Prepares one pubspec, keeping dependencies whose alias edits are unsupported.
void _stripUnavailableDependenciesInFile(Project project, String path) {
  final pubspec = _readPubspec(project.readFile(path)!);
  if (pubspec == null) {
    return;
  }

  final strippedEntries = <_StrippedDependency>[];
  for (final sectionName in ['dependencies', 'dev_dependencies', 'dependency_overrides']) {
    final section = pubspec.node.nodes[sectionName];
    if (section is YamlMap) {
      strippedEntries.addAll(_stripUnavailableDependenciesInSection(project, path, pubspec, sectionName, section));
    }
  }
  if (strippedEntries.isNotEmpty) {
    final lineEnding = pubspec.source.contains('\r\n') ? '\r\n' : '\n';
    final comments = strippedEntries.map((entry) => _commentOutEntry(entry, lineEnding));
    final updatedSource = '${pubspec.editor}$lineEnding${comments.join(lineEnding)}$lineEnding';
    project.writeFile(path, Uint8List.fromList(utf8.encode(updatedSource)));
  }
}

typedef _Pubspec = ({String source, YamlEditor editor, YamlMap node});
typedef _StrippedDependency = ({String source, String sectionName, String reason});

_Pubspec? _readPubspec(Uint8List bytes) {
  final String pubspecSource;
  final YamlEditor pubspecEditor;
  try {
    pubspecSource = utf8.decode(bytes);
    pubspecEditor = YamlEditor(pubspecSource);
  } on FormatException {
    // Leave invalid UTF-8 or YAML unchanged for the normal validation path.
    return null;
  }
  // Keep this snapshot: its spans refer to pubspecSource, even after editor
  // mutations. Reparsing sections from the edited document would shift them.
  final pubspecNode = pubspecEditor.parseAt([]);
  if (pubspecNode is! YamlMap) {
    return null;
  }
  return (source: pubspecSource, editor: pubspecEditor, node: pubspecNode);
}

/// Returns removed entries with their original source, section, and reason.
List<_StrippedDependency> _stripUnavailableDependenciesInSection(
  Project project,
  String path,
  _Pubspec pubspec,
  String sectionName,
  YamlMap dependencySection,
) {
  final strippedEntries = <_StrippedDependency>[];
  final packageDirectory = parentWorkspacePath(path);
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
      pubspec.editor.remove([sectionName, dependencyName]);
    } on AliasException {
      project.addImportWarning(
        'Dependency "$dependencyName" in $path ($sectionName) $unavailableReason, '
        'but was left unchanged because it uses a YAML alias or anchor. Consider removing it manually.',
      );
      continue;
    }
    strippedEntries.add((
      source: pubspec.source
          .substring(
            dependencyNameNode.span.start.offset,
            dependencyNode.span.end.offset,
          )
          .trimRight(),
      sectionName: sectionName,
      reason: unavailableReason,
    ));
    project.addImportWarning(
      'Dependency "$dependencyName" in $path ($sectionName) $unavailableReason and was not loaded.',
    );
  }
  return strippedEntries;
}

String _commentOutEntry(_StrippedDependency entry, String lineEnding) {
  final lineBreak = RegExp(r'\r\n|\r|\n');
  final entryLines = entry.source.split(lineBreak);
  final commentedLines = [for (final line in entryLines) line.isEmpty ? '' : '# $line'];
  if (commentedLines.first.isNotEmpty) {
    // A YAML path can span multiple lines; keep its explanation on a comment line.
    final reason = entry.reason.replaceAll(lineBreak, ' ');
    commentedLines[0] += ' # removed by DartPad from ${entry.sectionName} because it $reason.';
  }
  return commentedLines.join(lineEnding);
}

String? _unavailableDependencyReason(Project project, String packageDirectory, YamlMap dependencyNode) {
  if (dependencyNode.containsKey('git')) {
    return 'uses Git, which is not supported by DartPad';
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
