// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:yaml/yaml.dart';

import '../preview/models/run_mode.dart';
import '../shared/dart_source.dart';
import '../shared/sdk_info.dart';
import 'project_loader.dart';
import 'project_request.dart';
import 'project_source.dart';

/// Immutable startup options and resolved metadata
final class InitialProjectState {
  InitialProjectState._({
    required this.request,
    required List<String> files,
    required this.root,
    required this.entrypoint,
    required this.sdk,
    required this.mode,
    required this.hasPubspec,
  }) : files = List.unmodifiable(files);

  /// Resolves startup metadata from [contents] without retaining the project.
  factory InitialProjectState.resolve(ProjectRequest request, Project contents, List<SdkInfo> sdks) {
    final explicitFiles = request.files.isEmpty ? const <String>[] : _resolveExplicitFiles(contents, request.files);
    final explicitEntrypoint = _resolveOptionalFile(contents, request.entrypoint);

    final root = _resolveRoot(request, contents, [
      ...explicitFiles,
      ?explicitEntrypoint,
    ]);
    final readme = joinWorkspacePath(root, 'README.md');
    final implicitReadme = request.files.isEmpty && contents.containsFile(readme) ? readme : null;
    final sdk = _resolveSdk(request, contents, root, sdks);
    final entrypoint = _resolveEntrypoint(contents, root, [...explicitFiles, ?implicitReadme], explicitEntrypoint);
    final files = [
      if (request.files.isNotEmpty) ...explicitFiles else if (implicitReadme != null) implicitReadme else ?entrypoint,
    ];
    final mode = _resolveRunMode(request, contents, sdk, entrypoint);

    return InitialProjectState._(
      request: request,
      files: files,
      root: root,
      entrypoint: entrypoint,
      sdk: sdk,
      mode: mode,
      hasPubspec: contents.containsFile(joinWorkspacePath(root, 'pubspec.yaml')),
    );
  }

  final ProjectRequest request;
  ProjectSource get source => request.source;
  final List<String> files;
  final String root;
  final String? entrypoint;
  final SdkInfo sdk;
  final RunMode mode;

  /// Whether [root] contained a pubspec when the initial metadata was resolved.
  final bool hasPubspec;
}

String _resolveFile(Project contents, String path) {
  final resolved = contents.resolvePath(path);
  if (!contents.containsFile(resolved)) {
    throw FormatException('Project file not found: $path.');
  }
  return resolved;
}

String? _resolveOptionalFile(Project contents, String? path) => path == null ? null : _resolveFile(contents, path);

List<String> _resolveExplicitFiles(Project contents, List<String> requestedFiles) {
  final files = <String>[];
  for (final path in requestedFiles) {
    final resolved = _resolveFile(contents, path);
    if (!files.contains(resolved)) {
      files.add(resolved);
    }
  }
  return files;
}

String _resolveRoot(ProjectRequest request, Project contents, List<String> relevantPaths) {
  final root = request.root != null
      ? ProjectLoader.normalizePath(request.root!, allowRoot: true)
      : _commonPackageRoot(contents, relevantPaths);
  if (root.isNotEmpty && !contents.paths.any((path) => path.startsWith('$root/'))) {
    throw FormatException('Project root not found: $root.');
  }
  return root;
}

SdkInfo _resolveSdk(ProjectRequest request, Project contents, String root, List<SdkInfo> availableSdks) {
  final sdkKind = request.sdk ?? (pubspecUsesFlutter(_pubspec(contents, root)) ? 'flutter' : 'dart');
  final matches = availableSdks.where(
    (sdk) =>
        sdk.isFlutter == (sdkKind == 'flutter') &&
        (request.sdkVersion == null || _sdkVersion(sdk) == request.sdkVersion),
  );
  if (matches.isEmpty) {
    throw FormatException(
      'SDK not available: $sdkKind${request.sdkVersion == null ? '' : ':${request.sdkVersion}'}.',
    );
  }
  return matches.first;
}

String? _resolveEntrypoint(
  Project contents,
  String root,
  List<String> files,
  String? explicitEntrypoint,
) {
  final candidates = [...files, joinWorkspacePath(root, 'lib/main.dart'), joinWorkspacePath(root, 'main.dart')];
  return explicitEntrypoint ?? candidates.where((path) => _projectFileHasMain(contents, path)).firstOrNull;
}

RunMode _resolveRunMode(ProjectRequest request, Project contents, SdkInfo sdk, String? entrypoint) {
  final mode = request.mode ?? _inferRunMode(contents, sdk, entrypoint);
  if (mode == RunMode.flutter && !sdk.isFlutter) {
    throw const FormatException('Flutter mode requires a Flutter SDK.');
  }
  return mode;
}

/// Version metadata may append a human-readable Dart build description.
String _sdkVersion(SdkInfo sdk) => (sdk.flutterVersion ?? sdk.dartVersion).split(' ').first;

String _commonPackageRoot(Project contents, List<String> paths) {
  if (paths.isEmpty) {
    return '';
  }
  var parent = parentWorkspacePath(paths.first);
  while (true) {
    if (paths.every((path) => parent.isEmpty || path.startsWith('$parent/')) &&
        contents.containsFile(joinWorkspacePath(parent, 'pubspec.yaml'))) {
      return parent;
    }
    if (parent.isEmpty) {
      return '';
    }
    parent = parentWorkspacePath(parent);
  }
}

Map<Object?, Object?> _pubspec(Project contents, String root) {
  final bytes = contents.readFile(joinWorkspacePath(root, 'pubspec.yaml'));
  if (bytes == null) {
    return const {};
  }
  final Object? yaml = loadYaml(utf8.decode(bytes));
  if (yaml is! Map<Object?, Object?>) {
    throw const FormatException('pubspec.yaml must contain a mapping.');
  }
  return yaml;
}

bool pubspecUsesFlutter(Map<Object?, Object?> pubspec) {
  final environment = pubspec['environment'];
  if (environment is Map<Object?, Object?> && environment['flutter'] != null) {
    return true;
  }
  if (pubspec['flutter'] != null) {
    return true;
  }
  for (final key in ['dependencies', 'dev_dependencies']) {
    final dependencies = pubspec[key];
    if (dependencies is Map<Object?, Object?> &&
        dependencies.values.any((value) => value is Map<Object?, Object?> && value['sdk'] == 'flutter')) {
      return true;
    }
  }
  return false;
}

bool _projectFileHasMain(Project project, String path) {
  if (!path.endsWith('.dart')) {
    return false;
  }
  final bytes = project.readFile(path);
  if (bytes == null) {
    return false;
  }
  try {
    return dartSourceHasMain(utf8.decode(bytes));
  } on FormatException {
    return false;
  }
}

RunMode _inferRunMode(Project project, SdkInfo sdk, String? entrypoint) {
  if (!sdk.isFlutter || entrypoint == null) {
    return RunMode.console;
  }
  final root = ProjectLoader.findProjectDirectory(project, entrypoint) ?? '';
  return RunMode.forEntrypoint(sdk: sdk, entrypoint: entrypoint, packageRoot: root);
}
