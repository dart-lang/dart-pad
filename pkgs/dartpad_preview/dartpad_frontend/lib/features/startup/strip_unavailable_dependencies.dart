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
    _stripUnavailableDependenciesInPackage(project, packageDirectory: packageDirectory);
  }
}

/// Prepares the pubspec and overrides files of one package directory.
///
/// Both files check membership against the original pubspec.yaml snapshot, so their
/// order does not matter. Each file is written once, after its changes are collected.
void _stripUnavailableDependenciesInPackage(Project project, {required String packageDirectory}) {
  final pubspec = _readPubspec(project, joinWorkspacePath(packageDirectory, 'pubspec.yaml'));
  final overrides = _readPubspec(project, joinWorkspacePath(packageDirectory, 'pubspec_overrides.yaml'));
  final namesInDependencies = _sectionNames(pubspec, sectionName: 'dependencies');
  if (pubspec != null) {
    _warnAboutUnavailableDependencies(project, file: pubspec);
    _amendFile(
      project,
      file: pubspec,
      sectionNames: const ['dev_dependencies', 'dependency_overrides'],
      namesInDependencies: namesInDependencies,
    );
  }
  if (overrides != null) {
    _amendFile(
      project,
      file: overrides,
      sectionNames: const ['dependency_overrides'],
      namesInDependencies: namesInDependencies,
    );
  }
}

typedef _Pubspec = ({
  String path,
  Uint8List bytes,
  String source,
  YamlEditor editor,
  YamlMap node,
});
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
typedef _Availability = ({
  bool isAvailable,
  String? unavailableReason,
});

/// Reads and parses the file at [path]. Returns null when it is missing, not UTF-8,
/// invalid YAML, or not a mapping.
_Pubspec? _readPubspec(Project project, String path) {
  final bytes = project.readFile(path);
  if (bytes == null) {
    return null;
  }
  final String source;
  try {
    source = utf8.decode(bytes);
  } on FormatException {
    return null;
  }
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
  return (path: path, bytes: bytes, source: source, editor: pubspecEditor, node: pubspecNode);
}

/// Names of the string-keyed entries in [sectionName] of the original [file], read before any edits.
Set<String> _sectionNames(_Pubspec? file, {required String sectionName}) {
  final section = file?.node.nodes[sectionName];
  if (section is! YamlMap) {
    return const <String>{};
  }
  return {
    for (final key in section.nodes.keys)
      if ((key as YamlNode).value case final String name) name,
  };
}

/// Warns about each unavailable entry in `dependencies`. These entries are never removed,
/// so the project may not resolve.
void _warnAboutUnavailableDependencies(Project project, {required _Pubspec file}) {
  final entries = _unavailableEntries(
    project,
    file: file,
    sectionName: 'dependencies',
    namesInDependencies: const <String>{},
  );
  for (final entry in entries) {
    project.addImportWarning(
      'Dependency "${entry.name}" in ${file.path} (dependencies) ${entry.reason}, and cannot be resolved.',
    );
  }
}

/// Removes unavailable entries from each of [sectionNames] and writes [file].
///
/// Writes the original bytes to a `*.original.yaml` backup and the amended file with one
/// commented entry per change. Writes nothing when no entry was removed.
void _amendFile(
  Project project, {
  required _Pubspec file,
  required List<String> sectionNames,
  required Set<String> namesInDependencies,
}) {
  final changes = [
    for (final sectionName in sectionNames)
      ..._collectDependencyAmendments(
        project,
        file: file,
        sectionName: sectionName,
        namesInDependencies: namesInDependencies,
      ),
  ];
  if (changes.isEmpty) {
    return;
  }
  final backupPath = file.path.replaceFirst(RegExp(r'\.yaml$'), '.original.dartpad.yaml');
  final comments = changes.map(_commentOutEntry);
  final amendedSource = '${file.editor}\n${comments.join('\n')}\n';
  project.writeFile(backupPath, file.bytes);
  project.writeFile(file.path, Uint8List.fromList(utf8.encode(amendedSource)));
  project.addImportWarning(
    'Created $backupPath with the original ${basenameWorkspacePath(file.path)} contents '
    'because unavailable entries were removed from it.',
  );
}

/// Removes unavailable entries of [sectionName] from the in-memory editor and returns them
/// as a collection of amendments to be applied to the pubspec file. Nothing is written to the project here.
List<_DependencyComment> _collectDependencyAmendments(
  Project project, {
  required _Pubspec file,
  required String sectionName,
  required Set<String> namesInDependencies,
}) {
  final amendments = <_DependencyComment>[];
  final entries = _unavailableEntries(
    project,
    file: file,
    sectionName: sectionName,
    namesInDependencies: namesInDependencies,
  );
  for (final entry in entries) {
    if (!_removeDependency(project, file: file, sectionName: sectionName, entry: entry)) {
      continue;
    }
    amendments.add((
      source: _entrySource(file, entry.nameNode, entry.node),
      sectionName: sectionName,
      reason: entry.reason,
    ));
  }
  return amendments;
}

/// Returns the entries of [sectionName] that cannot be loaded in DartPad.
///
/// Overrides whose names are in [namesInDependencies] are skipped, because removing them
/// would change how the same dependency resolves.
List<_UnavailableEntry> _unavailableEntries(
  Project project, {
  required _Pubspec file,
  required String sectionName,
  required Set<String> namesInDependencies,
}) {
  final section = file.node.nodes[sectionName];
  if (section is! YamlMap) {
    return const [];
  }
  final entries = <_UnavailableEntry>[];
  for (final dependencyEntry in section.nodes.entries) {
    final dependencyNameNode = dependencyEntry.key as YamlNode;
    final dependencyName = dependencyNameNode.value;
    final dependencyNode = dependencyEntry.value;
    if (dependencyName is! String || dependencyNode is! YamlMap) {
      continue;
    }
    if (sectionName == 'dependency_overrides' && namesInDependencies.contains(dependencyName)) {
      continue;
    }
    final availability = _dependencyAvailability(
      project,
      packageDirectory: parentWorkspacePath(file.path),
      dependencyNode: dependencyNode,
    );
    if (!availability.isAvailable) {
      entries.add((
        name: dependencyName,
        nameNode: dependencyNameNode,
        node: dependencyNode,
        reason: availability.unavailableReason!,
      ));
    }
  }
  return entries;
}

/// Removes one entry from the pubspec editor. Returns false and warns when yaml_edit
/// refuses the edit because the entry uses an alias or anchor.
bool _removeDependency(
  Project project, {
  required _Pubspec file,
  required String sectionName,
  required _UnavailableEntry entry,
}) {
  try {
    // yaml_edit refuses edits to aliases and anchors before changing the source.
    file.editor.remove([sectionName, entry.name]);
  } on AliasException {
    project.addImportWarning(
      'Dependency "${entry.name}" in ${file.path} ($sectionName) ${entry.reason}, '
      'but was left unchanged because it uses a YAML alias or anchor. Consider removing it manually.',
    );
    return false;
  }
  project.addImportWarning(
    'Dependency "${entry.name}" in ${file.path} ($sectionName) ${entry.reason} and was not loaded.',
  );
  return true;
}

/// Returns the original source of one map entry, from its key to the end of its value.
///
/// Alias keys and values resolve to anchored nodes, whose spans are not this entry's
/// text. Those entries use the key name and the anchored value text instead.
String _entrySource(_Pubspec file, YamlNode dependencyNameNode, YamlNode dependencyNode) {
  final source = file.source;
  final keyStart = dependencyNameNode.span.start.offset;
  final keyEnd = dependencyNameNode.span.end.offset;
  final valueStart = dependencyNode.span.start.offset;
  final valueEnd = dependencyNode.span.end.offset;
  final keySpanIsOwnText = keyEnd <= valueStart && _isKeySeparator(source.substring(keyEnd, valueStart));
  if (keySpanIsOwnText && valueEnd > valueStart) {
    return source.substring(keyStart, valueEnd).trimRight();
  }
  final keyText = keySpanIsOwnText ? source.substring(keyStart, keyEnd) : '${dependencyNameNode.value}';
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

String _commentOutEntry(_DependencyComment entry) {
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
  return commentedLines.join('\n');
}

/// Checks whether a dependency can be loaded in DartPad. The reason is set only when it cannot.
_Availability _dependencyAvailability(
  Project project, {
  required String packageDirectory,
  required YamlMap dependencyNode,
}) {
  if (dependencyNode.containsKey('git')) {
    return (isAvailable: false, unavailableReason: 'uses Git, which is not supported by DartPad');
  }
  final dependencyPath = dependencyNode['path'];
  if (dependencyPath is! String) {
    return (isAvailable: true, unavailableReason: null);
  }
  final dependencyDirectory = joinWorkspacePath(packageDirectory, dependencyPath);
  final isAbsolutePath = workspacePath.isAbsolute(dependencyPath);
  if (isAbsolutePath || !isWithinWorkspaceFolder(dependencyDirectory, '')) {
    return (
      isAvailable: false,
      unavailableReason:
          'uses ${isAbsolutePath ? 'absolute' : 'relative'} path "$dependencyPath", '
          'which is outside the imported workspace',
    );
  }
  final dependencyPubspecPath = joinWorkspacePath(dependencyDirectory, 'pubspec.yaml');
  if (!project.containsFile(dependencyPubspecPath)) {
    return (
      isAvailable: false,
      unavailableReason:
          'uses relative path "$dependencyPath", whose target package is not included in the imported workspace',
    );
  }
  return (isAvailable: true, unavailableReason: null);
}
