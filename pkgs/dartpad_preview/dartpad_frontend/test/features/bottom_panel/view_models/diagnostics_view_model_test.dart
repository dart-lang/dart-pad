// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:codemirror_dart/codemirror_dart.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/bottom_panel/view_models/diagnostics_view_model.dart';
import 'package:dartpad_frontend/features/editor/view_models/tabs_view_model.dart';
import 'package:test/test.dart';

final class _FakeWorkspace implements WorkspaceResourceApi {
  @override
  Stream<WorkspaceChangeEvent> get changeEvents => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeCodeMirrorLspClient implements CodeMirrorLspClient {
  @override
  Future<void> dispose() async {}

  @override
  void receiveFromServer(String message) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DiagnosticsViewModel', () {
    late StreamController<Object?> languageServerMessages;
    late StreamController<WorkspaceChangeEvent> workspaceEvents;
    late LanguageServerClient languageServerClient;
    late TabsViewModel tabs;
    late DiagnosticsViewModel viewModel;

    setUp(() {
      languageServerMessages = StreamController<Object?>();
      workspaceEvents = StreamController<WorkspaceChangeEvent>();
      languageServerClient = LanguageServerClient(
        languageServer: null,
        rootWorkspaceUri: Uri.parse('file:///workspace/'),
        editorRootUri: Uri.parse('file:///workspace/'),
        workspaceChangeEvents: workspaceEvents.stream,
        sendToLanguageServer: (_) {},
        languageServerMessages: languageServerMessages.stream,
        createCodeMirrorLspClient: (_, _) => _FakeCodeMirrorLspClient(),
      );
      tabs = TabsViewModel(
        workspaceResourceApi: _FakeWorkspace(),
        adapters: const [],
      );
      viewModel = DiagnosticsViewModel(tabs: tabs);
    });

    tearDown(() async {
      viewModel.dispose();
      tabs.dispose();
      await languageServerClient.dispose();
      await languageServerMessages.close();
      await workspaceEvents.close();
    });

    test('only includes diagnostics within the project root', () async {
      await _publishDiagnostics(languageServerClient, languageServerMessages, 'example/lib/main.dart');
      await _publishDiagnostics(languageServerClient, languageServerMessages, 'lib/main.dart');

      viewModel.attachLanguageServer(languageServerClient, projectRoot: 'example');

      await _publishDiagnostics(languageServerClient, languageServerMessages, 'example_other/main.dart');

      expect(
        viewModel.diagnostics.map((entry) => entry.fileName),
        ['example/lib/main.dart'],
      );
      expect(viewModel.hasMoreDiagnostics, isFalse);
      expect(languageServerClient.allDiagnostics, hasLength(3));
    });

    for (final entry in <String, String?>{'unset': null, 'the workspace root': ''}.entries) {
      test('includes all diagnostics when project root is ${entry.key}', () async {
        final projectRoot = entry.value;
        viewModel.attachLanguageServer(languageServerClient, projectRoot: projectRoot);

        await _publishDiagnostics(languageServerClient, languageServerMessages, 'example/lib/main.dart');
        await _publishDiagnostics(languageServerClient, languageServerMessages, 'lib/main.dart');

        expect(viewModel.diagnostics, hasLength(2));
      });
    }

    test('applies the display limit after filtering', () async {
      viewModel.attachLanguageServer(languageServerClient, projectRoot: 'example');

      await _publishDiagnostics(
        languageServerClient,
        languageServerMessages,
        'lib/unrelated.dart',
        count: DiagnosticsViewModel.maxDisplayedDiagnostics + 1,
      );
      await _publishDiagnostics(languageServerClient, languageServerMessages, 'example/lib/main.dart');

      expect(viewModel.diagnostics, hasLength(1));
      expect(viewModel.hasMoreDiagnostics, isFalse);

      await _publishDiagnostics(
        languageServerClient,
        languageServerMessages,
        'example/lib/main.dart',
        count: DiagnosticsViewModel.maxDisplayedDiagnostics + 1,
      );

      expect(
        viewModel.diagnostics,
        hasLength(DiagnosticsViewModel.maxDisplayedDiagnostics),
      );
      expect(viewModel.hasMoreDiagnostics, isTrue);
    });

    group('watchImportDiagnostics', () {
      late StreamController<WorkspaceChangeEvent> changes;
      late _CountingImportDiagnostics computeImportDiagnostics;

      setUp(() {
        changes = StreamController<WorkspaceChangeEvent>.broadcast();
        computeImportDiagnostics = _CountingImportDiagnostics(_importEntry('pubspec.yaml', 'before'));
        viewModel.setImportDiagnostics(computeImportDiagnostics.entries);
      });

      tearDown(() async {
        await changes.close();
      });

      test('replaces import problems after a pubspec modification', () async {
        viewModel.watchImportDiagnostics(
          _ChangeFakeWorkspace(changes.stream),
          computeImportDiagnostics: computeImportDiagnostics.call,
        );

        computeImportDiagnostics.entries = [_importEntry('pubspec.yaml', 'after')];
        changes.add(WorkspaceChangeEvent(type: WorkspaceChangeEventType.modify, path: 'pubspec.yaml'));
        await _settleImportRefresh();

        expect(viewModel.diagnostics.map((entry) => entry.diagnostic.message), ['after']);
        expect(computeImportDiagnostics.calls, 1);
      });

      test('recomputes when a resource is added or removed', () async {
        viewModel.watchImportDiagnostics(
          _ChangeFakeWorkspace(changes.stream),
          computeImportDiagnostics: computeImportDiagnostics.call,
        );

        changes.add(WorkspaceChangeEvent(type: WorkspaceChangeEventType.add, path: 'packages/local/pubspec.yaml'));
        await _settleImportRefresh();

        expect(computeImportDiagnostics.calls, 1);
      });

      test('recomputes after a pubspec_overrides.yaml modification', () async {
        viewModel.watchImportDiagnostics(
          _ChangeFakeWorkspace(changes.stream),
          computeImportDiagnostics: computeImportDiagnostics.call,
        );

        changes.add(WorkspaceChangeEvent(type: WorkspaceChangeEventType.modify, path: 'pubspec_overrides.yaml'));
        await _settleImportRefresh();

        expect(computeImportDiagnostics.calls, 1);
      });

      test('ignores modifications to other files', () async {
        viewModel.watchImportDiagnostics(
          _ChangeFakeWorkspace(changes.stream),
          computeImportDiagnostics: computeImportDiagnostics.call,
        );

        changes.add(WorkspaceChangeEvent(type: WorkspaceChangeEventType.modify, path: 'lib/main.dart'));
        await _settleImportRefresh();

        expect(computeImportDiagnostics.calls, 0);
      });

      test('debounces a burst of changes into one recompute', () async {
        viewModel.watchImportDiagnostics(
          _ChangeFakeWorkspace(changes.stream),
          computeImportDiagnostics: computeImportDiagnostics.call,
        );

        for (var index = 0; index < 5; index++) {
          changes.add(WorkspaceChangeEvent(type: WorkspaceChangeEventType.modify, path: 'pubspec.yaml'));
        }
        await _settleImportRefresh();

        expect(computeImportDiagnostics.calls, 1);
      });

      test('keeps language server problems when import problems refresh', () async {
        viewModel.attachLanguageServer(languageServerClient, projectRoot: null);
        await _publishDiagnostics(languageServerClient, languageServerMessages, 'lib/main.dart');
        viewModel.watchImportDiagnostics(
          _ChangeFakeWorkspace(changes.stream),
          computeImportDiagnostics: computeImportDiagnostics.call,
        );

        computeImportDiagnostics.entries = [_importEntry('pubspec.yaml', 'after')];
        changes.add(WorkspaceChangeEvent(type: WorkspaceChangeEventType.modify, path: 'pubspec.yaml'));
        await _settleImportRefresh();

        expect(viewModel.diagnostics.map((entry) => entry.fileName), containsAll(['lib/main.dart', 'pubspec.yaml']));
      });

      test('a new watch cancels the previous one', () async {
        final previousChanges = StreamController<WorkspaceChangeEvent>.broadcast();
        addTearDown(previousChanges.close);
        viewModel.watchImportDiagnostics(
          _ChangeFakeWorkspace(previousChanges.stream),
          computeImportDiagnostics: computeImportDiagnostics.call,
        );
        viewModel.watchImportDiagnostics(
          _ChangeFakeWorkspace(changes.stream),
          computeImportDiagnostics: computeImportDiagnostics.call,
        );

        previousChanges.add(WorkspaceChangeEvent(type: WorkspaceChangeEventType.modify, path: 'pubspec.yaml'));
        await _settleImportRefresh();

        expect(computeImportDiagnostics.calls, 0);
      });
    });
  });
}

/// Waits for the debounce window and the asynchronous recompute to finish.
Future<void> _settleImportRefresh() => Future<void>.delayed(DiagnosticsViewModel.importRefreshDelay * 3);

DiagnosticEntry _importEntry(String fileName, String message) => DiagnosticEntry(
  fileName,
  Diagnostic(line: 0, character: 0, message: message, severity: DiagnosticSeverity.warning),
);

final class _CountingImportDiagnostics {
  _CountingImportDiagnostics(DiagnosticEntry entry) : entries = [entry];

  List<DiagnosticEntry> entries;
  int calls = 0;

  Future<List<DiagnosticEntry>> call(WorkspaceResourceApi workspace) async {
    calls++;
    return entries;
  }
}

final class _ChangeFakeWorkspace implements WorkspaceResourceApi {
  _ChangeFakeWorkspace(this._changes);

  final Stream<WorkspaceChangeEvent> _changes;

  @override
  Stream<WorkspaceChangeEvent> get changeEvents => _changes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _publishDiagnostics(
  LanguageServerClient client,
  StreamController<Object?> messages,
  String path, {
  int count = 1,
}) async {
  final published = client.diagnosticsStream.first;
  messages.add({
    'method': 'textDocument/publishDiagnostics',
    'params': {
      'uri': 'file:///workspace/$path',
      'diagnostics': [
        for (var index = 0; index < count; index++)
          {
            'range': {
              'start': {'line': index, 'character': 0},
              'end': {'line': index, 'character': 1},
            },
            'message': 'Problem $index',
            'severity': 1,
          },
      ],
    },
  });
  await published;
}
