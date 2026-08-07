// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

final class _FakeLanguageServerClient implements LanguageServerClient {
  final List<Map<String, Object?>> appliedEdits = [];
  final List<(String, List<Object?>?)> executedCommands = [];

  @override
  JSObject createCodeMirrorExtension(String file) => JSArray();

  @override
  Future<void> applyWorkspaceEdit(Map<String, Object?> edit) async {
    appliedEdits.add(edit);
  }

  @override
  Future<void> executeCommand(String command, List<Object?>? arguments) async {
    executedCommands.add((command, arguments));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late JSObject lspPluginConstructor;
  late JSFunction originalPluginGet;
  late web.HTMLDivElement parent;
  late CodeMirrorEditor editor;
  late _FakeLanguageServerClient languageServerClient;
  late CodeActionsController controller;
  late List<Map<String, Object?>> responseActions;
  late Future<List<Map<String, Object?>>> Function() responseProvider;
  late String requestedMethod;
  late Map<String, Object?> requestedParams;
  late int requestCount;

  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;

    final namespace = web.window.getProperty<JSObject>('_codemirror'.toJS);
    lspPluginConstructor = namespace.getProperty<JSObject>('LSPPlugin'.toJS);
    originalPluginGet = lspPluginConstructor.getProperty<JSFunction>('get'.toJS);
  });

  setUp(() {
    responseActions = [];
    responseProvider = () async => responseActions;
    requestedMethod = '';
    requestedParams = {};
    requestCount = 0;
    languageServerClient = _FakeLanguageServerClient();
    parent = web.HTMLDivElement();
    web.document.body!.appendChild(parent);
    editor = CodeMirrorEditor(
      parent,
      file: 'lib/main.dart',
      initialDoc: 'final value = Widget();',
      onCodeActionRequested: () {
        unawaited(controller.triggerQuickFixes());
      },
      languageServerClient: languageServerClient,
    );
    controller = CodeActionsController(
      codeEditor: editor,
      file: 'lib/main.dart',
      getDiagnostics: () => [
        const DiagnosticEntry(
          'lib/main.dart',
          Diagnostic(
            line: 0,
            character: 14,
            message: 'Use const',
            severity: DiagnosticSeverity.info,
            raw: {
              'range': {
                'start': {'line': 0, 'character': 14},
                'end': {'line': 0, 'character': 22},
              },
              'message': 'Use const',
            },
          ),
        ),
      ],
      onStateChanged: () {},
    );

    final fakeClient = JSObject()
      ..setProperty('sync'.toJS, (() {}).toJS)
      ..setProperty(
        'request'.toJS,
        ((JSString method, JSObject params) {
          requestCount++;
          requestedMethod = method.toDart;
          requestedParams = (params.dartify() as Map).cast<String, Object?>();
          return responseProvider().then((actions) => actions.jsify()).toJS;
        }).toJS,
      );
    final fakePlugin = JSObject()
      ..setProperty('client'.toJS, fakeClient)
      ..setProperty('uri'.toJS, 'file:///workspace/lib/main.dart'.toJS)
      ..setProperty(
        'toPosition'.toJS,
        ((int offset) => {'line': 0, 'character': offset}.jsify()).toJS,
      )
      ..setProperty(
        'fromPosition'.toJS,
        ((JSObject position) {
          final map = (position.dartify() as Map).cast<String, Object?>();
          return map['character']! as int;
        }).toJS,
      );
    lspPluginConstructor.setProperty(
      'get'.toJS,
      ((cm.EditorView _) => fakePlugin).toJS,
    );
  });

  tearDown(() {
    controller.dispose();
    editor.destroy();
    parent.remove();
    lspPluginConstructor.setProperty('get'.toJS, originalPluginGet);
  });

  test('requests only quick fixes with overlapping diagnostics', () async {
    await controller.triggerQuickFixes(from: 14, to: 22);

    expect(requestedMethod, 'textDocument/codeAction');
    expect(requestedParams['range'], {
      'start': {'line': 0, 'character': 14},
      'end': {'line': 0, 'character': 22},
    });
    expect(requestedParams['context'], {
      'diagnostics': [
        {
          'range': {
            'start': {'line': 0, 'character': 14},
            'end': {'line': 0, 'character': 22},
          },
          'message': 'Use const',
        },
      ],
      'only': ['quickfix'],
      'triggerKind': 1,
    });
    expect(controller.showFloatingPanel, isTrue);
    expect(controller.codeActions, isEmpty);
  });

  test('reports unavailable quick fixes without opening the panel', () async {
    expect(await controller.hasQuickFixes(from: 14, to: 22), isFalse);

    expect(requestCount, 1);
    expect(controller.showFloatingPanel, isFalse);
    expect(controller.codeActions, isNull);
  });

  test('reuses the availability response when the action is triggered', () async {
    responseActions = [
      {'title': 'Use const', 'kind': 'quickfix'},
      {'title': 'Suppress lint', 'kind': 'quickfix'},
    ];

    expect(await controller.hasQuickFixes(from: 14, to: 22), isTrue);
    await controller.triggerQuickFixes(from: 14, to: 22);

    expect(requestCount, 1);
    expect(controller.codeActions, hasLength(2));
  });

  test('Ctrl+. requests quick fixes at the cursor', () async {
    editor.view.dom
        .querySelector('.cm-content')!
        .dispatchEvent(
          web.KeyboardEvent(
            'keydown',
            web.KeyboardEventInit(
              bubbles: true,
              cancelable: true,
              key: '.',
              code: 'Period',
              ctrlKey: true,
            ),
          ),
        );
    await pumpEventQueue();

    expect(requestedMethod, 'textDocument/codeAction');
    expect(requestedParams['range'], {
      'start': {'line': 0, 'character': 0},
      'end': {'line': 0, 'character': 0},
    });
  });

  test('applies a single quick fix edit and command immediately', () async {
    responseActions = [
      {
        'title': 'Use const',
        'kind': 'quickfix',
        'edit': {
          'changes': {
            'file:///workspace/lib/main.dart': [
              {
                'range': {
                  'start': {'line': 0, 'character': 14},
                  'end': {'line': 0, 'character': 14},
                },
                'newText': 'const ',
              },
            ],
          },
        },
        'command': {
          'command': 'dart.logAction',
          'arguments': ['useConst'],
        },
      },
    ];

    await controller.triggerQuickFixes(from: 14, to: 22);

    expect(languageServerClient.appliedEdits, hasLength(1));
    expect(languageServerClient.executedCommands, hasLength(1));
    expect(languageServerClient.executedCommands.single.$1, 'dart.logAction');
    expect(languageServerClient.executedCommands.single.$2, ['useConst']);
    expect(controller.showFloatingPanel, isFalse);
    expect(controller.codeActions, isNull);
  });

  test('shows multiple quick fixes without applying one', () async {
    responseActions = [
      {'title': 'Use const', 'kind': 'quickfix'},
      {'title': 'Suppress lint', 'kind': 'quickfix'},
      {'title': 'Extract method', 'kind': 'refactor.extract'},
    ];

    await controller.triggerQuickFixes(from: 14, to: 22);

    expect(controller.showFloatingPanel, isTrue);
    expect(
      controller.codeActions!.map((action) => action.title.toDart),
      ['Use const', 'Suppress lint'],
    );
    expect(languageServerClient.appliedEdits, isEmpty);
    expect(languageServerClient.executedCommands, isEmpty);
  });

  test('ignores a stale code-action response', () async {
    final firstResponse = Completer<List<Map<String, Object?>>>();
    responseProvider = () {
      if (requestCount == 1) {
        return firstResponse.future;
      }
      return Future.value([
        {'title': 'Current fix A', 'kind': 'quickfix'},
        {'title': 'Current fix B', 'kind': 'quickfix'},
      ]);
    };

    final firstRequest = controller.triggerQuickFixes(from: 14, to: 22);
    await controller.triggerQuickFixes(from: 0, to: 0);
    firstResponse.complete([
      {'title': 'Stale fix A', 'kind': 'quickfix'},
      {'title': 'Stale fix B', 'kind': 'quickfix'},
    ]);
    await firstRequest;

    expect(
      controller.codeActions!.map((action) => action.title.toDart),
      ['Current fix A', 'Current fix B'],
    );
  });
}
