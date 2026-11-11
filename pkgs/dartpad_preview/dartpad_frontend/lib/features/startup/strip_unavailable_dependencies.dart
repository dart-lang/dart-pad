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
/// Each amended file keeps its original bytes in a sibling `*.original.dartpad.yaml` file.
void stripUnavailableDependencies(Project project) {
  for (final packageDirectory in _packageDirectories(project)) {
    _stripUnavailableDependenciesInPackage(project, packageDirectory: packageDirectory);
  }
}

/// Returns the Problems entries for unavailable entries in [project] without changing it.
///
/// Checks the sections [stripUnavailableDependencies] checks, against the files as they are at call-time.
List<DiagnosticEntry> dependencyDiagnostics(Project project) {
  final diagnostics = <DiagnosticEntry>[];
  for (final packageDirectory in _packageDirectories(project)) {
    final pubspec = _readPubspec(project, joinWorkspacePath(packageDirectory, 'pubspec.yaml'));
    final overrides = _readPubspec(project, joinWorkspacePath(packageDirectory, 'pubspec_overrides.yaml'));
    final namesInDependencies = _sectionNames(pubspec, sectionName: 'dependencies');
    if (pubspec != null) {
      for (final sectionName in const ['dependencies', 'dev_dependencies', 'dependency_overrides']) {
        diagnostics.addAll(
          _sectionDiagnostics(
            project,
            file: pubspec,
            sectionName: sectionName,
            namesInDependencies: namesInDependencies,
            overrides: overrides,
          ),
        );
      }
    }
    if (overrides != null) {
      diagnostics.addAll(
        _sectionDiagnostics(
          project,
          file: overrides,
          sectionName: 'dependency_overrides',
          namesInDependencies: namesInDependencies,
        ),
      );
    }
  }
  return diagnostics;
}

/// Returns the [dependencyDiagnostics] of the files currently in [workspace].
///
/// Reads the pubspec files as they are now, so edits made after import are reflected.
Future<List<DiagnosticEntry>> dependencyDiagnosticsInWorkspace(WorkspaceResourceApi workspace) async {
  return dependencyDiagnostics(await _projectFromWorkspace(workspace));
}

/// Copies the files of [workspace] into a [Project] for read-only checks.
///
/// Only pubspec files are read. Other files are present as empty so that path checks still work.
Future<Project> _projectFromWorkspace(WorkspaceResourceApi workspace) async {
  final files = <ProjectFile>[];
  for (final resource in await workspace.listDirectory(path: '', recursive: true)) {
    if (resource.type != 'file') {
      continue;
    }
    final basename = basenameWorkspacePath(resource.path);
    final isPubspec = basename == 'pubspec.yaml' || basename == 'pubspec_overrides.yaml';
    final bytes = isPubspec ? await workspace.readFileAsBytes(resource.path) : Uint8List(0);
    files.add(ProjectFile(path: resource.path, bytes: bytes));
  }
  return Project(files);
}

/// The Problems entries for the unavailable entries of [sectionName] in [file].
List<DiagnosticEntry> _sectionDiagnostics(
  Project project, {
  required _Pubspec file,
  required String sectionName,
  required Set<String> namesInDependencies,
  _Pubspec? overrides,
}) => [
  for (final entry in _unavailableEntries(
    project,
    file: file,
    sectionName: sectionName,
    namesInDependencies: namesInDependencies,
    overrides: overrides,
  ))
    _dependencyDiagnostic(file.path, entry),
];

/// The directories of the packages in [project]. A package is a directory holding pubspec.yaml,
/// and its overrides need that snapshot.
Set<String> _packageDirectories(Project project) => {
  for (final path in project.paths)
    if (basenameWorkspacePath(path) == 'pubspec.yaml') parentWorkspacePath(path),
};

/// Prepares the pubspec and overrides files of one package directory.
///
/// Both files check membership against the original pubspec.yaml snapshot, so their
/// order does not matter. Each file is written once, after its changes are collected.
void _stripUnavailableDependenciesInPackage(Project project, {required String packageDirectory}) {
  final pubspec = _readPubspec(project, joinWorkspacePath(packageDirectory, 'pubspec.yaml'));
  final overrides = _readPubspec(project, joinWorkspacePath(packageDirectory, 'pubspec_overrides.yaml'));
  final namesInDependencies = _sectionNames(pubspec, sectionName: 'dependencies');
  if (pubspec != null) {
    _warnAboutUnavailableDependencies(project, file: pubspec, overrides: overrides);
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
  YamlNode node,
  String reason,
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
void _warnAboutUnavailableDependencies(Project project, {required _Pubspec file, _Pubspec? overrides}) {
  final entries = _unavailableEntries(
    project,
    file: file,
    sectionName: 'dependencies',
    namesInDependencies: const <String>{},
    overrides: overrides,
  );
  for (final entry in entries) {
    project.addImportWarning(
      'Dependency "${entry.name}" in ${file.path} (dependencies) ${entry.reason}, and cannot be resolved.',
    );
  }
}

/// The Problems tab entry for an unavailable `dependencies` entry in the pubspec at [path].
DiagnosticEntry _dependencyDiagnostic(String path, _UnavailableEntry entry) {
  return DiagnosticEntry(
    path,
    Diagnostic(
      line: entry.nameNode.span.start.line,
      character: entry.nameNode.span.start.column,
      message: 'Dependency "${entry.name}" ${entry.reason}, and cannot be resolved.',
      severity: DiagnosticSeverity.error,
    ),
  );
}

/// Removes unavailable entries from each of [sectionNames] and writes [file].
///
/// Writes the original bytes to a `*.original.dartpad.yaml` backup and the amended file with one
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
  final lineEnding = RegExp(r'\r\n|\r|\n').firstMatch(file.source)?.group(0) ?? '\n';
  final comments = changes.map((change) => _commentOutEntry(change, lineEnding: lineEnding));
  final amendedSource = '${file.editor}$lineEnding${comments.join(lineEnding)}$lineEnding';
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
/// would change how the same dependency resolves. For `dependencies`, an entry is checked
/// against the override that replaces it when [overrides] or [file] declares one.
List<_UnavailableEntry> _unavailableEntries(
  Project project, {
  required _Pubspec file,
  required String sectionName,
  required Set<String> namesInDependencies,
  _Pubspec? overrides,
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
    if (dependencyName is! String) {
      continue;
    }
    if (sectionName == 'dependency_overrides' && namesInDependencies.contains(dependencyName)) {
      continue;
    }
    final effectiveNode = sectionName == 'dependencies'
        ? _overrideFor(dependencyName, file: file, overrides: overrides) ?? dependencyNode
        : dependencyNode;
    final unavailableReason = _unavailableReason(
      project,
      packageDirectory: parentWorkspacePath(file.path),
      dependencyNode: effectiveNode,
    );
    if (unavailableReason case final reason?) {
      entries.add((
        name: dependencyName,
        nameNode: dependencyNameNode,
        node: dependencyNode,
        reason: reason,
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

String _commentOutEntry(_DependencyComment entry, {required String lineEnding}) {
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

/// Returns the override that pub applies to [name], or null when none is declared.
///
/// Pub applies `pubspec_overrides.yaml` over the `dependency_overrides` in `pubspec.yaml`.
YamlNode? _overrideFor(String name, {required _Pubspec file, _Pubspec? overrides}) {
  for (final source in [overrides, file]) {
    final section = source?.node.nodes['dependency_overrides'];
    if (section is YamlMap && section.nodes[name] != null) {
      return section.nodes[name];
    }
  }
  return null;
}

/// Returns why a dependency cannot be loaded in DartPad, or null when it can.
///
/// Only git and path sources can be unavailable. Hosted sources load from pub, so a
/// [dependencyNode] that is not a map (a version constraint such as `^1.0.0`, `any`,
/// or an empty value) is always available.
String? _unavailableReason(
  Project project, {
  required String packageDirectory,
  required YamlNode dependencyNode,
}) {
  if (dependencyNode is! YamlMap) {
    return null;
  }
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
    return 'uses ${isAbsolutePath ? 'absolute' : 'relative'} path "$dependencyPath", '
        'which is outside the imported workspace';
  }
  final dependencyPubspecPath = joinWorkspacePath(dependencyDirectory, 'pubspec.yaml');
  if (!project.containsFile(dependencyPubspecPath)) {
    return 'uses relative path "$dependencyPath", whose target package is not included in the imported workspace';
  }
  return null;
}
