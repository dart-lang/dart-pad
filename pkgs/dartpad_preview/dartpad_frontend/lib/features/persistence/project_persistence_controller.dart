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

/// Coordinates history, restore offers and autosave for one browser tab.
///
/// The app owns project loading and session replacement. This controller owns
/// the store and attaches a [WorkspacePersistenceController] to each session
/// once its editor tabs are ready.
final class ProjectPersistenceController extends ChangeNotifier {
  ProjectPersistenceController({
    required bool enabled,
    required this._restoreProject,
    ProjectStore? store,
    this.restoreOfferDuration = const Duration(seconds: 30),
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
          } else {
            _expireRestoreOffer();
          }
        });
    _pageHideSubscription = web.EventStreamProviders.pageHideEvent.forTarget(web.window).listen((_) {
      unawaited(_autosave?.flush());
    });
  }

  final ProjectStore? _store;
  final Future<void> Function(String projectId) _restoreProject;
  final Duration restoreOfferDuration;

  bool _available;
  bool _disposed = false;
  WorkspacePersistenceController? _autosave;
  Future<void>? _stopping;
  Future<void>? _closing;

  String? _projectId;
  String? get projectId => _autosave?.projectId ?? _projectId;

  PersistenceNotice? _notice;
  PersistenceNotice? get notice => _notice;

  ProjectRestoreOffer? _restoreOffer;
  ProjectRestoreOffer? get restoreOffer => _restoreOffer;
  Timer? _restoreOfferTimer;
  StreamSubscription<web.Event>? _visibilitySubscription;
  StreamSubscription<web.Event>? _pageHideSubscription;

  /// Stops the previous session before inspecting history. The caller checks
  /// its load generation before opening the selected project.
  Future<PersistenceLoadStrategy> prepareLoad(
    ProjectRequest request, {
    bool startFresh = false,
    String? restoreProjectId,
  }) async {
    _clearRestoreOffer();
    _notify();
    await stop();
    final history = await _readHistory();
    if (restoreProjectId != null) {
      return PersistenceLoadStrategy(restoreProjectId: restoreProjectId);
    }
    if (startFresh) {
      return const PersistenceLoadStrategy();
    }
    if (request.query.isEmpty) {
      return PersistenceLoadStrategy(restoreProjectId: history.firstOrNull?.id);
    }
    return PersistenceLoadStrategy(
      offerProjectId: history.where((entry) => entry.state.matchesQuery(request.query)).firstOrNull?.id,
    );
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

  void offerRestore(String projectId) {
    if (_disposed) {
      return;
    }
    _clearRestoreOffer();
    _restoreOffer = ProjectRestoreOffer(
      projectId: projectId,
      expires: DateTime.now().add(restoreOfferDuration),
      duration: restoreOfferDuration,
    );
    _restoreOfferTimer = Timer(restoreOfferDuration, () {
      _clearRestoreOffer();
      _notify();
    });
    _notify();
  }

  Future<void> restoreLastProject() async {
    _expireRestoreOffer();
    if (_restoreOffer case final offer?) {
      await _restoreProject(offer.projectId);
    }
  }

  void _expireRestoreOffer() {
    final offer = _restoreOffer;
    if (offer != null && !DateTime.now().isBefore(offer.expires)) {
      _clearRestoreOffer();
      _notify();
    }
  }

  void _clearRestoreOffer() {
    _restoreOfferTimer?.cancel();
    _restoreOfferTimer = null;
    _restoreOffer = null;
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
    _clearRestoreOffer();
    _closing = stop().whenComplete(() => _store?.close());
    super.dispose();
  }
}
