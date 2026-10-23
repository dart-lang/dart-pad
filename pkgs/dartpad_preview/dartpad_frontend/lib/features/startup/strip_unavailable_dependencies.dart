// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'project_loader.dart';

/// Removes unavailable dev_dependencies and dependency_overrides, appending their original
/// source as comments at the end of each pubspec, including their section and removal reason.
///
/// Path dependencies must point to a package supplied by the same source.
/// Git dependencies cannot be fetched by the browser runtime. Changes happen
/// once during import, so later user edits remain under the user's control.
/// Dependencies requiring unsupported alias edits are preserved with a warning.
///
/// Regular `dependencies` are never changed. An override whose name is also in
/// `dependencies` is kept, because removing it would change how that dependency resolves.
/// Each amended file keeps its original bytes in a sibling `*.original.yaml` file.
void stripUnavailableDependencies(Project project) {
  // A package is a directory holding pubspec.yaml; its overrides need that snapshot.
  final packageDirectories = <String>{
    for (final path in project.paths)
      if (basenameWorkspacePath(path) == 'pubspec.yaml') parentWorkspacePath(path),
  };
  for (final packageDirectory in packageDirectories) {
    _stripUnavailableDependenciesInPackage(project, packageDirectory);
  }
}

/// Prepares the pubspec and overrides files of one package directory.
///
/// Membership checks use the original pubspec.yaml snapshot. Files are written only
/// after every change has been collected.
void _stripUnavailableDependenciesInPackage(Project project, String packageDirectory) {
  final pubspecPath = joinWorkspacePath(packageDirectory, 'pubspec.yaml');
  final overridesPath = joinWorkspacePath(packageDirectory, 'pubspec_overrides.yaml');

  final pubspecBytes = project.readFile(pubspecPath);
  final pubspecSource = pubspecBytes == null ? null : _decodeUtf8(pubspecBytes);
  final pubspec = pubspecSource == null ? null : _readPubspec(pubspecSource);
  // Regular dependencies are never stripped, so they produce no change or warning.
  final dependencyNames = _sectionNames(pubspec, 'dependencies');
  final pubspecChanges = pubspec == null
      ? const <_DependencyComment>[]
      : [
          ..._removeUnavailableEntries(
            project,
            pubspecPath,
            pubspec,
            'dev_dependencies',
            const <Object?>{},
          ),
          ..._removeUnavailableEntries(
            project,
            pubspecPath,
            pubspec,
            'dependency_overrides',
            dependencyNames,
          ),
        ];

  final overridesBytes = project.readFile(overridesPath);
  final overridesSource = overridesBytes == null ? null : _decodeUtf8(overridesBytes);
  final overrides = overridesSource == null ? null : _readPubspec(overridesSource);
  final overridesChanges = overrides == null
      ? const <_DependencyComment>[]
      : _removeUnavailableEntries(
          project,
          overridesPath,
          overrides,
          'dependency_overrides',
          dependencyNames,
        );
  if (overridesBytes != null && overridesSource == null) {
    _warnAboutNonUtf8Overrides(
      project,
      packageDirectory,
      overridesPath,
      overridesBytes,
      dependencyNames,
    );
  }

  if (pubspec != null && pubspecChanges.isNotEmpty) {
    _writeAmendedFile(
      project,
      pubspecPath,
      'pubspec.original.yaml',
      pubspecBytes!,
      pubspec,
      pubspecChanges,
      _lineEnding(pubspec.source),
    );
  }
  if (overrides != null && overridesChanges.isNotEmpty) {
    // Without a newline of its own, the overrides file uses the pubspec.yaml line ending.
    final lineEndingSource = overrides.source.contains('\n') ? overrides.source : (pubspec?.source ?? '');
    _writeAmendedFile(
      project,
      overridesPath,
      'pubspec_overrides.original.yaml',
      overridesBytes!,
      overrides,
      overridesChanges,
      _lineEnding(lineEndingSource),
    );
  }
}

typedef _Pubspec = ({String source, YamlEditor editor, YamlMap node});
typedef _DependencyComment = ({
  String source,
  String sectionName,
  String reason,
});
typedef _UnavailableEntry = ({
  String name,
  YamlNode nameNode,
  YamlMap node,
  String reason,
});

/// Returns null when the source is invalid YAML or does not contain a mapping.
_Pubspec? _readPubspec(String source) {
  final YamlEditor pubspecEditor;
  try {
    pubspecEditor = YamlEditor(source);
  } on FormatException {
    // Leave invalid YAML unchanged for the normal validation path.
    return null;
  }
  // Keep this snapshot: its spans refer to source, even after editor
  // mutations. Reparsing sections from the edited document would shift them.
  final pubspecNode = pubspecEditor.parseAt([]);
  if (pubspecNode is! YamlMap) {
    return null;
  }
  return (source: source, editor: pubspecEditor, node: pubspecNode);
}

/// Names of the entries in [sectionName] of the original [document].
Set<Object?> _sectionNames(_Pubspec? document, String sectionName) {
  final section = document?.node.nodes[sectionName];
  if (section is! YamlMap) {
    return const <Object?>{};
  }
  return {for (final key in section.nodes.keys) (key as YamlNode).value};
}

/// Removes unavailable entries from [sectionName] and returns them as changes.
///
/// Entries whose names are in [keptNames] are left alone without a warning.
List<_DependencyComment> _removeUnavailableEntries(
  Project project,
  String path,
  _Pubspec document,
  String sectionName,
  Set<Object?> keptNames,
) {
  final changes = <_DependencyComment>[];
  final entries = _unavailableEntries(
    project,
    parentWorkspacePath(path),
    document,
    sectionName,
    keptNames,
  );
  for (final entry in entries) {
    if (!_removeDependency(project, path, document, sectionName, entry.name, entry.reason)) {
      continue;
    }
    changes.add((
      source: _entrySource(document, entry.nameNode, entry.node),
      sectionName: sectionName,
      reason: entry.reason,
    ));
  }
  return changes;
}

/// Returns the entries of [sectionName] that cannot be loaded, excluding [keptNames].
List<_UnavailableEntry> _unavailableEntries(
  Project project,
  String packageDirectory,
  _Pubspec document,
  String sectionName,
  Set<Object?> keptNames,
) {
  final section = document.node.nodes[sectionName];
  if (section is! YamlMap) {
    return const [];
  }
  final entries = <_UnavailableEntry>[];
  for (final dependencyEntry in section.nodes.entries) {
    final dependencyNameNode = dependencyEntry.key as YamlNode;
    final dependencyName = dependencyNameNode.value;
    final dependencyNode = dependencyEntry.value;
    if (dependencyName is! String || dependencyNode is! YamlMap || keptNames.contains(dependencyName)) {
      continue;
    }
    final unavailableReason = _unavailableDependencyReason(
      project,
      packageDirectory,
      dependencyNode,
    );
    if (unavailableReason != null) {
      entries.add((
        name: dependencyName,
        nameNode: dependencyNameNode,
        node: dependencyNode,
        reason: unavailableReason,
      ));
    }
  }
  return entries;
}

/// Warns about unavailable overrides in a non-UTF-8 overrides file, which is never rewritten.
void _warnAboutNonUtf8Overrides(
  Project project,
  String packageDirectory,
  String path,
  Uint8List bytes,
  Set<Object?> keptNames,
) {
  // Decode leniently only to find the entries that would have been removed.
  final document = _readPubspec(utf8.decode(bytes, allowMalformed: true));
  if (document == null) {
    return;
  }
  final entries = _unavailableEntries(
    project,
    packageDirectory,
    document,
    'dependency_overrides',
    keptNames,
  );
  for (final entry in entries) {
    project.addImportWarning(
      'Dependency "${entry.name}" in $path (dependency_overrides) ${entry.reason}, '
      'but was left unchanged because $path is not valid UTF-8. Consider removing it manually.',
    );
  }
}

/// Writes the original bytes to [backupName] beside [path], then the edited document with
/// one commented entry per change.
void _writeAmendedFile(
  Project project,
  String path,
  String backupName,
  Uint8List originalBytes,
  _Pubspec document,
  List<_DependencyComment> changes,
  String lineEnding,
) {
  final backupPath = joinWorkspacePath(parentWorkspacePath(path), backupName);
  final comments = changes.map((entry) => _commentOutEntry(entry, lineEnding));
  final amendedSource = '${document.editor}$lineEnding${comments.join(lineEnding)}$lineEnding';
  project.writeFile(backupPath, originalBytes);
  project.writeFile(path, Uint8List.fromList(utf8.encode(amendedSource)));
  project.addImportWarning(
    'Created $backupPath with the original ${basenameWorkspacePath(path)} contents '
    'because unavailable entries were removed from it.',
  );
}

/// Removes one entry from the pubspec editor. Returns false and warns when yaml_edit
/// refuses the edit because the entry uses an alias or anchor.
bool _removeDependency(
  Project project,
  String path,
  _Pubspec pubspec,
  String sectionName,
  String dependencyName,
  String unavailableReason,
) {
  try {
    // yaml_edit refuses edits to aliases and anchors before changing the source.
    pubspec.editor.remove([sectionName, dependencyName]);
  } on AliasException {
    project.addImportWarning(
      'Dependency "$dependencyName" in $path ($sectionName) $unavailableReason, '
      'but was left unchanged because it uses a YAML alias or anchor. Consider removing it manually.',
    );
    return false;
  }
  project.addImportWarning(
    'Dependency "$dependencyName" in $path ($sectionName) $unavailableReason and was not loaded.',
  );
  return true;
}

/// Returns the original source of one map entry, from its key to the end of its value.
///
/// Alias keys and values resolve to anchored nodes, whose spans are not this entry's
/// text. Those entries use the key name and the anchored value text instead.
String _entrySource(
  _Pubspec pubspec,
  YamlNode dependencyNameNode,
  YamlNode dependencyNode,
) {
  final source = pubspec.source;
  final keyStart = dependencyNameNode.span.start.offset;
  final keyEnd = dependencyNameNode.span.end.offset;
  final valueStart = dependencyNode.span.start.offset;
  final valueEnd = dependencyNode.span.end.offset;
  final keyIsOwn = keyEnd <= valueStart && _isKeySeparator(source.substring(keyEnd, valueStart));
  if (keyIsOwn && valueEnd > valueStart) {
    return source.substring(keyStart, valueEnd).trimRight();
  }
  final keyText = keyIsOwn ? source.substring(keyStart, keyEnd) : '${dependencyNameNode.value}';
  if (valueEnd > valueStart) {
    return '$keyText: ${source.substring(valueStart, valueEnd).trimRight()}';
  }
  return '$keyText:';
}

/// Whether the text between a key and its value is only a colon, optionally followed by comments.
bool _isKeySeparator(String text) {
  final colon = RegExp(r'^[ \t]*:').firstMatch(text);
  if (colon == null) {
    return false;
  }
  return text.substring(colon.end).split('\n').every((line) {
    final trimmed = line.trim();
    return trimmed.isEmpty || trimmed.startsWith('#');
  });
}

String _commentOutEntry(_DependencyComment entry, String lineEnding) {
  final lineBreak = RegExp(r'\r\n|\r|\n');
  final entryLines = entry.source.split(lineBreak);
  final commentedLines = [
    for (final line in entryLines) line.isEmpty ? '' : '# $line',
  ];
  if (commentedLines.first.isNotEmpty) {
    // A YAML path can span multiple lines; keep its explanation on a comment line.
    final singleLineReason = entry.reason.replaceAll(lineBreak, ' ');
    commentedLines[0] += ' # removed by DartPad from ${entry.sectionName} because it $singleLineReason.';
  }
  return commentedLines.join(lineEnding);
}

String? _decodeUtf8(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

String _lineEnding(String source) => source.contains('\r\n') ? '\r\n' : '\n';

String? _unavailableDependencyReason(
  Project project,
  String packageDirectory,
  YamlMap dependencyNode,
) {
  if (dependencyNode.containsKey('git')) {
    return 'uses Git, which is not supported by DartPad';
  }
  final dependencyPath = dependencyNode['path'];
  if (dependencyPath is! String) {
    return null;
  }
  final dependencyDirectory = joinWorkspacePath(
    packageDirectory,
    dependencyPath,
  );
  final isAbsolutePath = workspacePath.isAbsolute(dependencyPath);
  if (isAbsolutePath || !isWithinWorkspaceFolder(dependencyDirectory, '')) {
    return 'uses ${isAbsolutePath ? 'absolute' : 'relative'} path "$dependencyPath", which is outside the imported workspace';
  }
  final dependencyPubspecPath = joinWorkspacePath(
    dependencyDirectory,
    'pubspec.yaml',
  );
  if (!project.containsFile(dependencyPubspecPath)) {
    return 'uses relative path "$dependencyPath", whose target package is not included in the imported workspace';
  }
  return null;
}
