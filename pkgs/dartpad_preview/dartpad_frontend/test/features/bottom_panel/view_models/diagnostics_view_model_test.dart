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
  });
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
