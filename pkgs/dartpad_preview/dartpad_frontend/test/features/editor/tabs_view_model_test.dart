// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:codemirror_dart/codemirror_dart.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/bottom_panel/view_models/diagnostics_view_model.dart';
import 'package:dartpad_frontend/features/editor/codemirror/code_mirror_tab.dart';
import 'package:dartpad_frontend/features/editor/codemirror/code_mirror_tab_adapter.dart';
import 'package:dartpad_frontend/features/editor/components/code_action_panel.dart';
import 'package:dartpad_frontend/features/editor/components/editor_stack.dart';
import 'package:dartpad_frontend/features/editor/components/editor_tab_bar.dart';
import 'package:dartpad_frontend/features/editor/view_models/tabs_view_model.dart';
import 'package:dartpad_frontend/features/startup/example_project.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

/// An in-memory workspace resource API used by editor view-model tests.
final class FakeWorkspaceController implements WorkspaceResourceApi {
  final Map<String, String> files = {
    'lib/main.dart': 'void main() {}',
    'pubspec.yaml': 'name: test',
  };
  Error? readError;
  Error? writeError;

  @override
  Stream<WorkspaceChangeEvent> get changeEvents => const Stream<WorkspaceChangeEvent>.empty();

  @override
  Future<void> get changeEventsReady => Future.value();

  @override
  Future<bool> fileExist(String uri) async => files.containsKey(uri);

  @override
  Future<bool> folderExist(String uri) async => false;

  @override
  Future<String> readFileAsText(String uri) async {
    if (readError case final error?) {
      throw error;
    }
    return files[uri]!;
  }

  @override
  Future<void> writeFileFromText(String uri, String content) async {
    if (writeError case final error?) {
      throw error;
    }
    files[uri] = content;
  }

  @override
  Future<Uint8List> readFileAsBytes(String uri) async => Uint8List.fromList(files[uri]!.codeUnits);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Runs the [TabsViewModel] test suite.
void main() {
  late FakeWorkspaceController workspace;
  final externalFiles = <Uri, String>{};
  Completer<void>? externalReadGate;
  var runCount = 0;
  TabsViewModel? tabs;
  DiagnosticsViewModel? diagnostics;

  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;
  });

  setUp(() async {
    workspace = FakeWorkspaceController();
    externalFiles.clear();
    externalReadGate = null;
    runCount = 0;
    tabs = TabsViewModel(
      workspaceResourceApi: workspace,
      adapters: [
        CodeMirrorTabAdapter(
          readExternalFile: (uri) async {
            await externalReadGate?.future;
            return externalFiles[uri]!;
          },
          onRun: () => runCount++,
        ),
      ],
    );
    diagnostics = DiagnosticsViewModel(tabs: tabs!);
    await openExampleProject(tabs!.openWorkspaceFile);
  });

  tearDown(() async {
    diagnostics?.dispose();
    diagnostics = null;
    tabs?.dispose();
    tabs = null;
  });

  test('missing workspace files report an opening error', () async {
    await expectLater(tabs!.openWorkspaceFile('missing.dart'), throwsStateError);
    expect(tabs!.errorMessage, 'Could not open missing.dart.');
  });

  test('cancelled external loads propagate without an error message', () async {
    final uri = Uri.parse('file:///sdk/core.dart');
    externalFiles[uri] = 'class Object {}';
    externalReadGate = Completer<void>();
    final opening = tabs!.openExternalFile(uri);
    final completed = expectLater(opening, throwsA(isA<TabOpenCancelledException>()));
    await Future<void>.delayed(Duration.zero);
    tabs!.disposeAllTabs();
    externalReadGate!.complete();
    await completed;
    expect(tabs!.errorMessage, isNull);
    expect(tabs!.openTabs, isEmpty);
  });

  test('opens main.dart with main.dart active', () {
    expect(
      tabs!.openTabs.map((tab) => tab.path),
      ['lib/main.dart'],
    );
    expect(tabs!.activeFile, 'lib/main.dart');
  });

  testClient('opens external URIs as navigable read-only tabs', (tester) async {
    final uri = Uri.parse('file:///pub-cache/example/lib/example.dart');
    externalFiles[uri] = 'class Example {}';

    await tabs!.openExternalFile(uri);
    final tab = tabs!.activeTab! as ExternalCodeMirrorTab;
    tester.pumpComponent(tab.build());
    await pumpEventQueue();

    expect(tabs!.activeFile, uri.toString());
    expect(tab.origin, EditorTabOrigin.external);
    expect(tab.keepAlive, isFalse);
    expect(tab.content, 'class Example {}');
    expect(tab.editor.view.contentDOM.contentEditable, 'true');
    expect(tab.hasUnsavedChanges, isFalse);

    tab.editor.text = 'changed';
    expect(tab.content, 'class Example {}');
    final filesBeforeSave = Map<String, String>.of(workspace.files);
    await tab.save();
    expect(workspace.files, filesBeforeSave);
    tab.goToPosition(0, 6);
    expect(tab.editor.view.state.selection.main.head, 6);

    final contextMenuEvent = web.MouseEvent(
      'contextmenu',
      web.MouseEventInit(bubbles: true, cancelable: true),
    );
    tab.container.dispatchEvent(contextMenuEvent);
    expect(contextMenuEvent.defaultPrevented, isFalse);

    tab.editor.focus();
    final saveEvent = web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: 's', ctrlKey: true, bubbles: true, cancelable: true),
    );
    tab.editor.view.contentDOM.dispatchEvent(saveEvent);
    expect(saveEvent.defaultPrevented, isTrue);

    tab.editor.view.contentDOM.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Enter', ctrlKey: true, bubbles: true, cancelable: true),
      ),
    );
    expect(runCount, 1);

    expect(tabs!.closeFile(uri.toString()), isTrue);
    expect(tabs!.getTab(uri.toString()), isNull);
    expect(tab.dispose, returnsNormally);
  });

  test('workspace tabs support edits, discard, and saving after rename', () async {
    await tabs!.openWorkspaceFile('pubspec.yaml');
    final tab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    expect(tab.origin, EditorTabOrigin.workspace);
    expect(tab.keepAlive, isTrue);

    await tab.applyEdits([
      {
        'range': {
          'start': {'line': 0, 'character': 6},
          'end': {'line': 0, 'character': 10},
        },
        'newText': 'updated',
      },
    ]);
    expect(tab.content, 'name: updated');
    expect(tab.hasUnsavedChanges, isTrue);
    tab.discardUnsavedChanges();
    expect(tab.content, 'name: test');
    expect(tab.hasUnsavedChanges, isFalse);

    tab.rename('renamed.yaml');
    expect(tab.editor.file, 'renamed.yaml');
    expect(tab.codeActionsController.file, 'renamed.yaml');
    tab.editor.text = 'name: renamed';
    await tab.save();
    expect(workspace.files['renamed.yaml'], 'name: renamed');
    expect(workspace.files['pubspec.yaml'], 'name: test');
    expect(tab.hasUnsavedChanges, isFalse);
  });

  test('reports and rethrows external file load failures', () async {
    final uri = Uri.parse('file:///pub-cache/missing.dart');

    await expectLater(
      tabs!.openExternalFile(uri),
      throwsA(anything),
    );

    expect(tabs!.errorMessage, 'Could not open missing.dart.');
    expect(tabs!.activeFile, 'lib/main.dart');
  });

  test('workspace load failures are reported and rethrown, and success clears the message', () async {
    final error = StateError('internal read failure');
    workspace.readError = error;

    await expectLater(
      tabs!.openWorkspaceFile('pubspec.yaml'),
      throwsA(same(error)),
    );
    expect(tabs!.errorMessage, 'Could not open pubspec.yaml.');
    expect(tabs!.activeFile, 'lib/main.dart');

    workspace.readError = null;
    await tabs!.openWorkspaceFile('pubspec.yaml');
    expect(tabs!.errorMessage, isNull);
    expect(tabs!.activeFile, 'pubspec.yaml');
  });

  test('diagnostic navigation activates the target and keeps the requested position', () async {
    await diagnostics!.openDiagnostic(
      'pubspec.yaml',
      const Diagnostic(
        line: 0,
        character: 4,
        message: 'Test problem',
        severity: DiagnosticSeverity.error,
      ),
    );
    await pumpEventQueue();

    expect(tabs!.activeFile, 'pubspec.yaml');
    final pubspecTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    expect(pubspecTab.editor.view.state.selection.main.head, 4);
  });

  test('diagnostic navigation reports read failures and keeps the active tab', () async {
    workspace.files['broken.dart'] = 'void main() {}';
    workspace.readError = StateError('internal read failure');

    await expectLater(
      diagnostics!.openDiagnostic(
        'broken.dart',
        const Diagnostic(
          line: 0,
          character: 0,
          message: 'Test problem',
          severity: DiagnosticSeverity.error,
        ),
      ),
      throwsA(same(workspace.readError)),
    );
    await pumpEventQueue();

    expect(tabs!.errorMessage, 'Could not open broken.dart.');
    expect(tabs!.activeFile, 'lib/main.dart');
  });

  test('allows every clean tab including the last tab to close', () async {
    await tabs!.openWorkspaceFile('pubspec.yaml');
    expect(tabs!.closeFile('lib/main.dart'), isTrue);
    expect(tabs!.activeFile, 'pubspec.yaml');

    expect(tabs!.closeFile('pubspec.yaml'), isTrue);
    expect(tabs!.openTabs, isEmpty);
    expect(tabs!.activeTab, isNull);
    expect(tabs!.activeFile, isEmpty);
  });

  test('requires explicit discard permission for a dirty tab', () {
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    mainTab.editor.text = '${mainTab.content}\n// dirty';

    expect(tabs!.closeFile('lib/main.dart'), isFalse);
    expect(tabs!.openTabs.map((tab) => tab.path), contains('lib/main.dart'));
    expect(mainTab.hasUnsavedChanges, isTrue);

    expect(
      tabs!.closeFile('lib/main.dart', discardChanges: true),
      isTrue,
    );
    expect(mainTab.hasUnsavedChanges, isFalse);
    expect(mainTab.content, 'void main() {}');
  });

  test('save-all writes dirty YAML without formatting', () async {
    await tabs!.openWorkspaceFile('pubspec.yaml');
    final pubspecTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    pubspecTab.editor.text = '${pubspecTab.content}\nversion: 1.0.0';

    await tabs!.saveAllTabs();

    expect(
      workspace.files['pubspec.yaml'],
      'name: test\nversion: 1.0.0',
    );
    expect(pubspecTab.hasUnsavedChanges, isFalse);
  });

  test('save-all errors hide internal details', () async {
    await tabs!.openWorkspaceFile('pubspec.yaml');
    final pubspecTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    pubspecTab.editor.text = '${pubspecTab.content}\nversion: 1.0.0';
    workspace.writeError = StateError('internal write failure');

    await expectLater(
      tabs!.saveAllTabs(),
      throwsA(isA<StateError>()),
    );
    await pumpEventQueue();

    expect(tabs!.errorMessage, 'Could not save all files.');
    expect(tabs!.errorMessage, isNot(contains('Bad state')));
  });

  testClient('autosaves dirty tab when editor loses focus', (tester) async {
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    final outsideButton = web.HTMLButtonElement();
    web.document.body!.appendChild(mainTab.container);
    web.document.body!.appendChild(outsideButton);
    addTearDown(() {
      mainTab.container.remove();
      outsideButton.remove();
    });

    mainTab.editor.text = 'void main() { print("autosaved"); }';
    expect(mainTab.hasUnsavedChanges, isTrue);

    mainTab.editor.focus();
    await pumpEventQueue();
    outsideButton.focus();
    await pumpEventQueue();

    expect(mainTab.hasUnsavedChanges, isFalse);
    expect(workspace.files['lib/main.dart'], 'void main() { print("autosaved"); }');
  });

  testClient('autosaves dirty tab when switching tabs', (tester) async {
    await tabs!.openWorkspaceFile('pubspec.yaml');
    tabs!.switchFile('lib/main.dart');
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    mainTab.editor.text = 'void main() { print("switched"); }';
    expect(mainTab.hasUnsavedChanges, isTrue);

    tabs!.switchFile('pubspec.yaml');
    await pumpEventQueue();

    expect(mainTab.hasUnsavedChanges, isFalse);
    expect(workspace.files['lib/main.dart'], 'void main() { print("switched"); }');
  });

  testClient('renders one dirty indicator and a close action for every tab', (tester) async {
    await tabs!.openWorkspaceFile('pubspec.yaml');
    tabs!.switchFile('lib/main.dart');
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    mainTab.editor.text = '${mainTab.content}\n// dirty';

    tester.pumpComponent(
      EditorTabBar(
        openTabs: tabs!.openTabs,
        activeFile: tabs!.activeFile,
        onSwitchFile: tabs!.switchFile,
        onCloseFile: tabs!.closeFile,
      ),
    );

    expect(web.document.querySelectorAll('.editor-tab-dirty-dot').length, 1);
    expect(web.document.querySelectorAll('.editor-tab-action.save').length, 0);
    expect(web.document.querySelectorAll('.editor-tab-action.close').length, 2);
  });

  testClient('dirty close honors cancellation and confirmed discard', (tester) async {
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    mainTab.editor.text = '${mainTab.content}\n// dirty';
    var shouldDiscard = false;

    tester.pumpComponent(
      EditorTabBar(
        openTabs: tabs!.openTabs,
        activeFile: tabs!.activeFile,
        onSwitchFile: tabs!.switchFile,
        onCloseFile: tabs!.closeFile,
        confirmDiscard: (_) => shouldDiscard,
      ),
    );

    final closeButton = web.document.querySelector('[aria-label="Close main.dart"]')! as web.HTMLButtonElement;
    closeButton.click();
    await pumpEventQueue();
    expect(tabs!.openTabs.map((tab) => tab.path), contains('lib/main.dart'));

    shouldDiscard = true;
    closeButton.click();
    await pumpEventQueue();
    expect(tabs!.openTabs.map((tab) => tab.path), isNot(contains('lib/main.dart')));
    expect(mainTab.hasUnsavedChanges, isFalse);
  });

  testClient('closing all tabs leaves an empty editor stack', (tester) async {
    await tabs!.openWorkspaceFile('pubspec.yaml');
    tabs!
      ..closeFile('lib/main.dart')
      ..closeFile('pubspec.yaml');

    tester.pumpComponent(
      EditorStack(
        openTabs: tabs!.openTabs,
        activeFile: tabs!.activeFile,
        overlay: const Component.fragment([]),
      ),
    );

    expect(web.document.querySelectorAll('.editor-tab-slot').length, 0);
  });

  testClient('quick-fix panel renders choices and applies the selected action', (tester) async {
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    final controller = mainTab.codeActionsController
      ..showFloatingPanel = true
      ..codeActions = [
        LSPCodeAction({'title': 'Use const', 'kind': 'quickfix'}.jsify() as JSObject),
        LSPCodeAction({'title': 'Suppress lint', 'kind': 'quickfix'}.jsify() as JSObject),
      ];

    tester.pumpComponent(mainTab.build());
    await pumpEventQueue();

    final buttons = web.document.querySelectorAll('.code-action-btn');
    expect(buttons.length, 2);
    expect(buttons.item(0)!.textContent, 'Use const');
    expect(buttons.item(1)!.textContent, 'Suppress lint');
    expect(web.document.activeElement, same(buttons.item(0)));

    buttons
        .item(0)!
        .dispatchEvent(
          web.KeyboardEvent(
            'keydown',
            web.KeyboardEventInit(key: 'ArrowDown', bubbles: true, cancelable: true),
          ),
        );
    expect(web.document.activeElement, same(buttons.item(1)));

    buttons
        .item(1)!
        .dispatchEvent(
          web.KeyboardEvent(
            'keydown',
            web.KeyboardEventInit(key: 'ArrowUp', bubbles: true, cancelable: true),
          ),
        );
    expect(web.document.activeElement, same(buttons.item(0)));

    buttons
        .item(0)!
        .dispatchEvent(
          web.KeyboardEvent(
            'keydown',
            web.KeyboardEventInit(key: 'ArrowDown', bubbles: true, cancelable: true),
          ),
        );

    buttons
        .item(1)!
        .dispatchEvent(
          web.KeyboardEvent(
            'keydown',
            web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true),
          ),
        );
    await pumpEventQueue();

    expect(controller.showFloatingPanel, isFalse);
    expect(controller.codeActions, isNull);
  });

  testClient('Escape closes the quick-fix panel and restores editor focus', (tester) async {
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    final controller = mainTab.codeActionsController
      ..showFloatingPanel = true
      ..codeActions = [
        LSPCodeAction({'title': 'Use const', 'kind': 'quickfix'}.jsify() as JSObject),
        LSPCodeAction({'title': 'Suppress lint', 'kind': 'quickfix'}.jsify() as JSObject),
      ];

    tester.pumpComponent(mainTab.build());
    await pumpEventQueue();

    web.document.activeElement!.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true),
      ),
    );
    await pumpEventQueue();

    expect(controller.showFloatingPanel, isFalse);
    expect(web.document.activeElement, same(mainTab.editor.view.dom.querySelector('.cm-content')));
  });

  testClient('quick-fix panel reports no results and closes on outside click', (tester) async {
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    final controller = mainTab.codeActionsController
      ..showFloatingPanel = true
      ..codeActions = [];

    tester.pumpComponent(CodeActionPanel(controller: controller));
    await pumpEventQueue();

    expect(web.document.querySelector('.code-action-empty-item')!.textContent, 'No code actions available');

    web.document.body!.dispatchEvent(
      web.MouseEvent('mousedown', web.MouseEventInit(bubbles: true)),
    );
    await pumpEventQueue();

    expect(controller.showFloatingPanel, isFalse);
  });

  testClient('quick-fix panel adjusts position above when near screen bottom', (tester) async {
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    final controller = mainTab.codeActionsController
      ..showFloatingPanel = true
      ..panelLeft = 50
      ..panelTop = (web.window.innerHeight - 20).toDouble()
      ..anchorTop = (web.window.innerHeight - 40).toDouble()
      ..anchorBottom = (web.window.innerHeight - 20).toDouble()
      ..codeActions = [
        LSPCodeAction({'title': 'Wrap with Center', 'kind': 'refactor'}.jsify() as JSObject),
        LSPCodeAction({'title': 'Wrap with Container', 'kind': 'refactor'}.jsify() as JSObject),
      ];

    tester.pumpComponent(CodeActionPanel(controller: controller));
    await pumpEventQueue();

    final panel = web.document.querySelector('.code-action-floating-panel') as web.HTMLElement;
    final topStyle = panel.style.top;
    expect(topStyle, isNotEmpty);
    final topValue = double.parse(topStyle.replaceAll('px', ''));
    expect(topValue, lessThan(controller.anchorTop));
  });

  testClient('right-click contextmenu positions cursor when outside selection', (tester) async {
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    mainTab.editor.text = 'void main() {\n  print("hello");\n}';
    // Set selection initially at position 0
    mainTab.editor.view.dispatch(
      TransactionSpec(selection: EditorSelection.single(0)),
    );

    // Get coords for position 10
    final coords = mainTab.editor.view.coordsAtPos(10);
    if (coords != null) {
      mainTab.container.dispatchEvent(
        web.MouseEvent(
          'contextmenu',
          web.MouseEventInit(
            bubbles: true,
            cancelable: true,
            clientX: ((coords.left + coords.right) / 2).round(),
            clientY: ((coords.top + coords.bottom) / 2).round(),
          ),
        ),
      );
      await pumpEventQueue();

      expect(mainTab.editor.view.state.selection.main.anchor, 10);
    }
  });

  testClient('right-click contextmenu preserves selection when inside existing selection', (tester) async {
    final mainTab = tabs!.activeTab! as WorkspaceCodeMirrorTab;
    mainTab.editor.text = 'void main() {\n  print("hello");\n}';
    // Set selection from 5 to 15
    mainTab.editor.view.dispatch(
      TransactionSpec(selection: EditorSelection.single(5, 15)),
    );

    // Get coords for position 10 (inside range 5..15)
    final coords = mainTab.editor.view.coordsAtPos(10);
    if (coords != null) {
      mainTab.container.dispatchEvent(
        web.MouseEvent(
          'contextmenu',
          web.MouseEventInit(
            bubbles: true,
            cancelable: true,
            clientX: ((coords.left + coords.right) / 2).round(),
            clientY: ((coords.top + coords.bottom) / 2).round(),
          ),
        ),
      );
      await pumpEventQueue();

      expect(mainTab.editor.view.state.selection.main.from, 5);
      expect(mainTab.editor.view.state.selection.main.to, 15);
    }
  });
}
