// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';

import '../editor/models/tab_descriptor.dart';
import '../preview/models/run_mode.dart';
import '../shared/sdk_info.dart';
import '../startup/initial_project_state.dart';
import '../startup/project_loader.dart';
import '../startup/project_request.dart';

/// One recoverable working copy, including text not yet saved by the editor.
final class PersistedProjectState {
  PersistedProjectState({
    required this.query,
    required this.sdk,
    required this.root,
    required this.entrypoint,
    required this.mode,
    required this.tabs,
    required this.activeFile,
    required this.files,
    required this.folders,
  });

  final Map<String, List<String>> query;
  final SdkInfo sdk;
  final String root;
  final String? entrypoint;
  final RunMode mode;
  final List<TabDescriptor> tabs;
  final String activeFile;
  final Map<String, Uint8List> files;
  final List<String> folders;

  Project get project => Project([
    for (final entry in files.entries) ProjectFile(path: entry.key, bytes: entry.value),
  ]);

  /// Compare decoded options; parameter order is irrelevant, value order is not.
  bool matchesQuery(Map<String, List<String>> other) {
    if (query.length != other.length) {
      return false;
    }
    return query.entries.every((entry) {
      final values = other[entry.key];
      return values != null &&
          values.length == entry.value.length &&
          Iterable<int>.generate(values.length).every((i) => values[i] == entry.value[i]);
    });
  }

  SdkInfo resolveSdk(List<SdkInfo> available) =>
      available
          .where(
            (value) =>
                value.id == sdk.id &&
                value.dartVersion == sdk.dartVersion &&
                value.flutterVersion == sdk.flutterVersion,
          )
          .firstOrNull ??
      available.where((value) => value.isFlutter == sdk.isFlutter).firstOrNull ??
      (throw StateError('The SDK for your previous work is no longer available.'));

  InitialProjectState initialProject(List<SdkInfo> available) => InitialProjectState.restore(
    request: ProjectRequest.fromUri(Uri(queryParameters: query)),
    root: root,
    entrypoint: entrypoint != null && files.containsKey(entrypoint) ? entrypoint : null,
    sdk: resolveSdk(available),
    mode: mode,
    hasPubspec: files.containsKey(joinWorkspacePath(root, 'pubspec.yaml')),
  );

  Map<String, Object?> metadata() => {
    'schemaVersion': 1,
    'query': query,
    'sdk': sdk.toJson(),
    'root': root,
    'entrypoint': entrypoint,
    'mode': mode.name,
    'tabs': [
      for (final tab in tabs) {'path': tab.path, 'origin': tab.origin.name},
    ],
    'activeFile': activeFile,
    'folders': folders,
  };

  factory PersistedProjectState.decode(Map<String, Object?> data, Map<String, Uint8List> files) {
    if (data['schemaVersion'] != 1) {
      throw const FormatException('Unsupported saved project version.');
    }
    final sdk = SdkInfo.fromJson(data['sdk'] as Map<String, Object?>);
    if (sdk == null) {
      throw const FormatException('Invalid saved SDK.');
    }
    final root = ProjectLoader.normalizePath(data['root'] as String, allowRoot: true);
    final entrypoint = data['entrypoint'] as String?;
    if (entrypoint != null) {
      ProjectLoader.normalizePath(entrypoint);
    }
    for (final path in files.keys) {
      ProjectLoader.normalizePath(path);
    }
    final folders = (data['folders'] as List<Object?>).cast<String>().toList(growable: false);
    for (final path in folders) {
      ProjectLoader.normalizePath(path);
    }
    final tabs = [
      for (final tab in (data['tabs'] as List<Object?>).cast<Map<String, Object?>>())
        TabDescriptor(path: tab['path'] as String, origin: EditorTabOrigin.values.byName(tab['origin'] as String)),
    ];
    for (final tab in tabs.where((tab) => tab.origin == EditorTabOrigin.workspace)) {
      ProjectLoader.normalizePath(tab.path);
    }
    return PersistedProjectState(
      query: (data['query'] as Map<String, Object?>).map(
        (key, value) => MapEntry(key, (value as List<Object?>).cast<String>().toList(growable: false)),
      ),
      sdk: sdk,
      root: root,
      entrypoint: entrypoint,
      mode: RunMode.values.byName(data['mode'] as String),
      tabs: tabs,
      activeFile: data['activeFile'] as String,
      files: files,
      folders: folders,
    );
  }
}

/// Excludes `.dart_tool/` metadata because Pub regenerates it.
bool isPersistentProjectPath(String path) => !path.split('/').contains('.dart_tool');
