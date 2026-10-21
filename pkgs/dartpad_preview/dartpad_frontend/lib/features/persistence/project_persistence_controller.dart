// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../shared/sdk_info.dart';
import '../startup/project_request.dart';
import '../workspace/workspace_session.dart';
import 'indexed_db_project_store.dart';
import 'project_persistence_state.dart';
import 'project_store.dart';
import 'workspace_persistence_controller.dart';

/// Coordinates history and autosave for one browser tab.
///
/// The app owns project loading and session replacement. This controller owns
/// the store and attaches a [WorkspacePersistenceController] to each session
/// once its editor tabs are ready.
final class ProjectPersistenceController extends ChangeNotifier {
  ProjectPersistenceController({
    required bool enabled,
    ProjectStore? store,
  }) : _store = enabled ? store ?? IndexedDbProjectStore() : null,
       _available = enabled {
    if (!enabled) {
      return;
    }
    _visibilitySubscription = const web.EventStreamProvider<web.Event>('visibilitychange')
        .forTarget(web.document)
        .listen((_) {
          if (web.document.visibilityState == 'hidden') {
            unawaited(_autosave?.flush());
          }
        });
    _pageHideSubscription = web.EventStreamProviders.pageHideEvent.forTarget(web.window).listen((_) {
      unawaited(_autosave?.flush());
    });
  }

  final ProjectStore? _store;

  bool _available;
  bool _disposed = false;
  WorkspacePersistenceController? _autosave;
  Future<void>? _stopping;
  Future<void>? _closing;

  String? _projectId;
  String? get projectId => _autosave?.projectId ?? _projectId;

  /// Session id of the tab's current project, set by [prepareLoad].
  int? _sessionId;

  PersistenceNotice? _notice;
  PersistenceNotice? get notice => _notice;

  StreamSubscription<web.Event>? _visibilitySubscription;
  StreamSubscription<web.Event>? _pageHideSubscription;

  /// Stops the previous session before inspecting history. The caller checks
  /// its load generation before opening the selected project.
  Future<PersistenceLoadStrategy> prepareLoad(ProjectRequest request, {bool startFresh = false}) async {
    await stop();
    final history = await _readHistory();
    _sessionId = null;
    if (request.parameters.isSourced) {
      return _resolveSourcedRequest(request, history, startFresh: startFresh);
    }
    return _resolveBareRequest(history, startFresh: startFresh);
  }

  /// A bare URL always selects the single scratch project.
  PersistenceLoadStrategy _resolveBareRequest(List<StoredProject> history, {required bool startFresh}) {
    final scratch = startFresh ? null : history.where((entry) => entry.state.isBareScratch).firstOrNull;
    return PersistenceLoadStrategy(restoreProjectId: scratch?.id);
  }

  /// Restores the entry saved under the requested session id.
  /// Otherwise, given no or an unknown id loads the source under a newly minted id.
  Future<PersistenceLoadStrategy> _resolveSourcedRequest(
    ProjectRequest request,
    List<StoredProject> history, {
    required bool startFresh,
  }) async {
    final requested = _requestedSessionId(request);
    if (!startFresh && requested != null) {
      final match = history
          .where((entry) => entry.state.sessionId == requested && entry.state.matchesQuery(request.query))
          .firstOrNull;
      if (match != null) {
        _sessionId = requested;
        return PersistenceLoadStrategy(restoreProjectId: match.id);
      }
    }
    final minted = await _reserveSessionId();
    _sessionId = minted;
    return PersistenceLoadStrategy(mintedSessionId: minted);
  }

  int? _requestedSessionId(ProjectRequest request) => request.parameters.session?.value;

  /// Returns null when storage is unavailable, leaving the URL without a session id.
  Future<int?> _reserveSessionId() async {
    if (!_available || _disposed) {
      return null;
    }
    try {
      return await _store!.reserveSessionId();
    } catch (_) {
      _available = false;
      _notice = const ProjectHistoryUnavailable();
      _notify();
      return null;
    }
  }

  Future<List<StoredProject>> _readHistory() async {
    if (!_available || _disposed) {
      return [];
    }
    try {
      return await _store!.list();
    } catch (_) {
      _available = false;
      _notice = const ProjectHistoryUnavailable();
      _notify();
      return [];
    }
  }

  /// Reads the latest snapshot. Attachment happens only after the app
  /// successfully opens its files.
  Future<StoredProject> read(String id) async {
    if (!_available || _disposed) {
      throw StateError('Local project storage is unavailable.');
    }
    final project = await _store!.read(id);
    if (project == null) {
      throw StateError('The saved project is no longer available.');
    }
    return project;
  }

  void reportRestoredSdk({required SdkInfo saved, required SdkInfo actual}) {
    if (saved.dartVersion != actual.dartVersion || saved.flutterVersion != actual.flutterVersion) {
      _notice = RestoredWithDifferentSdk(actual);
      _notify();
    }
  }

  /// Starts saving a prepared session. Omit [projectId] to create a new entry.
  /// Call and await [stop] before replacing an attached session.
  void attach(WorkspaceSession session, {String? projectId}) {
    if (!_available || _disposed) {
      return;
    }
    assert(_autosave == null && _stopping == null);
    _projectId = projectId;
    late final WorkspacePersistenceController autosave;
    autosave = WorkspacePersistenceController(
      session: session,
      store: _store!,
      projectId: projectId,
      sessionId: _sessionId,
      onError: (_) {
        if (identical(_autosave, autosave)) {
          _reportSaveFailure();
        }
      },
    );
    _autosave = autosave;
  }

  Future<void> flush() => _autosave?.flush() ?? Future.value();

  /// All callers share the final-save barrier before disposing a session.
  Future<void> stop() {
    if (_stopping case final stopping?) {
      return stopping;
    }
    final autosave = _autosave;
    if (autosave == null) {
      return Future.value();
    }
    return _stopping = autosave
        .stop()
        .then((_) {
          _projectId = autosave.projectId;
        })
        .whenComplete(() {
          _autosave = null;
          _stopping = null;
        });
  }

  void _reportSaveFailure() {
    if (_disposed) {
      return;
    }
    _notice = const ProjectSaveFailed();
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Completes the final save and store cleanup triggered by [dispose].
  Future<void> get closed => _closing ?? Future.value();

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _visibilitySubscription?.cancel();
    _pageHideSubscription?.cancel();
    _closing = stop().whenComplete(() => _store?.close());
    super.dispose();
  }
}
