// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';

import '../editor/models/tab_descriptor.dart';
import '../workspace/workspace_session.dart';
import 'persisted_project_state.dart';
import 'project_store.dart';

/// Persists saved workspace files and session metadata, independently of worker sync.
final class WorkspacePersistenceController {
  WorkspacePersistenceController({
    required this.session,
    required this.store,
    this._projectId,
    required this.onError,
    this.debounce = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 1),
  }) {
    final api = session.repository.workspaceResourceApi;
    _filesSubscription = api.changeEvents.listen((event) {
      if (isPersistentProjectPath(event.path)) {
        _changed();
      }
    });
    _entrypoint = session.preview.entrypoint;
    _mode = session.preview.previewMode.name;
    _tabs = session.tabSnapshot;
    _activeFile = session.tabs.activeFile;
    session.tabs.addListener(_tabsChanged);
    session.preview.addListener(_previewChanged);
    _changed();
  }

  final WorkspaceSession session;
  final ProjectStore store;
  String? _projectId;
  String? get projectId => _projectId;
  final void Function(Object error) onError;
  final Duration debounce;
  final Duration maxDelay;
  late final StreamSubscription<WorkspaceChangeEvent> _filesSubscription;
  Timer? _debounceTimer;
  Timer? _maxTimer;
  Future<void>? _writing;
  Future<void>? _stopping;
  bool _dirty = false;
  bool _stopped = false;
  String? _entrypoint;
  late String _mode;
  late List<TabDescriptor> _tabs;
  String? _activeFile;

  void _tabsChanged() {
    final tabs = session.tabSnapshot;
    final activeFile = session.tabs.activeFile;
    if (activeFile == _activeFile &&
        tabs.length == _tabs.length &&
        Iterable<int>.generate(tabs.length).every(
          (i) => tabs[i].path == _tabs[i].path && tabs[i].origin == _tabs[i].origin,
        )) {
      return;
    }
    _tabs = tabs;
    _activeFile = activeFile;
    _changed();
  }

  void _previewChanged() {
    final entrypoint = session.preview.entrypoint;
    final mode = session.preview.previewMode.name;
    if (entrypoint == _entrypoint && mode == _mode) {
      return;
    }
    _entrypoint = entrypoint;
    _mode = mode;
    _changed();
  }

  void _changed() {
    if (_stopped) {
      return;
    }
    _dirty = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(flush()));
    _maxTimer ??= Timer(maxDelay, () => unawaited(flush()));
  }

  Future<void> flush() {
    _cancelTimers();
    if (_writing case final writing?) {
      return writing;
    }
    if (!_dirty) {
      return Future.value();
    }
    return _writing = _save().whenComplete(() => _writing = null);
  }

  Future<void> _save() async {
    try {
      while (_dirty) {
        _dirty = false;
        final snapshot = await _capture();
        // Capture may yield during file reads. Retry if files or metadata changed.
        if (_dirty) {
          continue;
        }
        final id = _projectId;
        if (id == null) {
          _projectId = (await store.create(snapshot)).id;
        } else {
          await store.write(id, snapshot);
        }
      }
    } catch (error) {
      // Keep the snapshot pending for the next workspace change or explicit flush.
      // Do not retry here: persistent failures must not create a busy loop.
      _dirty = true;
      onError(error);
    }
  }

  Future<PersistedProjectState> _capture() async {
    final api = session.repository.workspaceResourceApi;
    final resources = await api.listDirectory(uri: '', recursive: true);
    final files = <String, Uint8List>{};
    final folders = <String>[];
    for (final resource in resources) {
      if (!isPersistentProjectPath(resource.path)) {
        continue;
      }
      if (resource.type == 'folder') {
        folders.add(resource.path);
      } else if (await api.fileExist(resource.path)) {
        files[resource.path] = Uint8List.fromList(await api.readFileAsBytes(resource.path));
      }
    }
    return PersistedProjectState(
      query: session.initialProject.request.query,
      sdk: session.repository.sdk,
      root: session.initialProject.root,
      entrypoint: session.preview.entrypoint,
      mode: session.preview.previewMode,
      tabs: [
        for (final tab in session.tabSnapshot)
          if (tab.origin == EditorTabOrigin.system || files.containsKey(tab.path))
            TabDescriptor(path: tab.path, origin: tab.origin),
      ],
      activeFile: session.tabs.activeFile,
      files: files,
      folders: folders,
    );
  }

  /// Cancels change listeners and pending timers, and flushes any pending writes to [store].
  Future<void> stop() => _stopping ??= _stop();

  Future<void> _stop() async {
    // Local file writes enqueue asynchronous change notifications. Let those
    // arrive before removing the listener, without inventing a change on stop.
    await Future<void>.delayed(Duration.zero);
    _stopped = true;
    _cancelTimers();
    session.tabs.removeListener(_tabsChanged);
    session.preview.removeListener(_previewChanged);
    await _filesSubscription.cancel();
    await flush();
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _maxTimer?.cancel();
    _debounceTimer = null;
    _maxTimer = null;
  }
}
