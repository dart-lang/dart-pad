// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/app.dart';
import 'package:dartpad_frontend/features/bottom_panel/views/bottom_panel.dart';
import 'package:dartpad_frontend/features/editor/components/editor_shell.dart';
import 'package:dartpad_frontend/features/preview/models/preview_state.dart';
import 'package:dartpad_frontend/features/preview/view/preview_container.dart';
import 'package:dartpad_frontend/features/shared/components/shortcut_definitions.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:dartpad_frontend/features/shared/panel_presentation_state.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/startup/strip_unavailable_dependencies.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/features/workspace/embed_runtime_controller.dart';
import 'package:jaspr/dom.dart' show div;
import 'package:jaspr/jaspr.dart' show StatefulElement;
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../../worker_fixture.dart';
import '../persistence/persistence_fixture.dart';

import 'initial_project_state_test.dart' show contents;

void main() {
  TestWorker.captureAssetBaseUrl();
  final startupWorkerAssets = Uri.base.resolve('../../fixtures/startup_worker/');
  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;
  });

  testClient('waits for project resolution before creating the correct SDK worker and opens initial tabs', (
    tester,
  ) async {
    final download = Completer<Project>();
    WorkspaceRepository? created;
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        initialUri: Uri.parse('?file=README.md&file=lib/main.dart'),
        loadSource: (_) => download.future,
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
          expect(sdk.isFlutter, isFalse);
          expect(deferWorker, isFalse);
          return created = WorkspaceRepository(
            events: events,
            taskStatus: taskStatus,
            sdk: sdk,
            workspaceResourceApi: localApi!,
            workspaceFuture: Completer<Workspace>().future,
          );
        },
      ),
    );
    await pumpEventQueue();
    expect(created, isNull);
    expect(web.document.querySelector('.editor-shell .editor-area'), isNotNull);
    expect(web.document.querySelector('.editor-tab-bar'), isNotNull);
    expect(web.document.body!.textContent, isNot(contains('Loading project')));
    expect(web.document.querySelector('.app-shell > .task-status-anchor'), isNull);
    expect(web.document.querySelector('.app-footer .task-status-trigger'), isNotNull);
    download.complete(
      contents({'README.md': '# Project', 'lib/main.dart': 'void main() {}', 'pubspec.yaml': 'name: demo'}),
    );
    await pumpEventQueue();
    expect(created, isNotNull);
    expect(await created!.workspaceResourceApi.fileExist('lib/main.dart'), isTrue);
    final tabs = web.document.querySelectorAll('.editor-tab-name');
    expect([for (var i = 0; i < tabs.length; i++) tabs.item(i)!.textContent], ['README.md', 'main.dart']);
    expect(web.document.querySelector('.editor-tab.active')!.textContent, contains('README.md'));
    expect(web.document.querySelector('.app-shell > .task-status-anchor'), isNull);
    expect(web.document.querySelector('.app-footer .task-status-trigger'), isNotNull);
  });

  testClient('command palette shortcut closes the shortcuts dialog', (tester) async {
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
            WorkspaceRepository(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              workspaceResourceApi: localApi!,
              workspaceFuture: Completer<Workspace>().future,
            ),
      ),
    );
    await pumpEventQueue();

    (web.document.querySelector('button[aria-label="Keyboard shortcuts"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();
    expect(web.document.querySelector('.shortcuts-dialog'), isNotNull);

    web.document.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          key: 'p',
          ctrlKey: !isMac,
          metaKey: isMac,
          shiftKey: true,
          bubbles: true,
          cancelable: true,
        ),
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('.shortcuts-dialog'), isNull);
    expect(web.document.querySelector('.command-palette'), isNotNull);

    (web.document.querySelector('button[aria-label="Keyboard shortcuts"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(web.document.querySelector('.command-palette'), isNull);
    expect(web.document.querySelector('.shortcuts-dialog'), isNotNull);
  });

  testClient('invalid SDK version shows an actionable error without starting a worker', (tester) async {
    var created = false;
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        initialUri: Uri.parse('?sdk=dart:0.0.0'),
        loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
          created = true;
          throw StateError('Must not create a worker');
        },
      ),
    );
    await pumpEventQueue();
    expect(created, isFalse);
    expect(web.document.body!.textContent, contains('SDK not available: dart:0.0.0'));
  });

  testClient('reports stripped import dependencies as warnings before resolving', (tester) async {
    final project = contents({
      'pubspec.yaml': 'name: demo\ndev_dependencies:\n  flutter_goldens:\n    path: ../../script/flutter_goldens\n',
    });
    stripUnavailableDependencies(project);
    final logs = <LogEvent>[];
    WorkspaceRepository? repository;
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        initialUri: Uri.parse('?package=demo'),
        loadSource: (_) async => project,
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
          final subscription = events.on<LogEvent>().listen(logs.add);
          addTearDown(subscription.cancel);
          return repository = WorkspaceRepository(
            events: events,
            sdk: sdk,
            taskStatus: taskStatus,
            workspaceResourceApi: localApi!,
            workspaceFuture: Completer<Workspace>().future,
          );
        },
      ),
    );
    await pumpEventQueue();
    expect(logs, hasLength(1));
    expect(logs.single.level, Level.WARNING);
    expect(logs.single.message, contains('Dependency "flutter_goldens"'));
    expect(logs.single.message, contains('outside the imported workspace'));
    expect(
      await repository!.workspaceResourceApi.readFileAsText('pubspec.yaml'),
      contains(
        '# flutter_goldens: # removed by DartPad from dev_dependencies because it uses relative path '
        '"../../script/flutter_goldens", which is outside the imported workspace.',
      ),
    );
  });

  group('panel layout retention', () {
    Future<void> mountApp(
      ClientTester tester, {
      required int width,
      bool embed = true,
      List<String> files = const [],
      Completer<Project>? download,
      int split = 70,
      List<String> panelHints = const [],
    }) async {
      final originalWidth = _getOwnPropertyDescriptor(web.window, 'innerWidth'.toJS);
      addTearDown(() async {
        tester.binding.detachRootComponent();
        await pumpEventQueue();
        if (originalWidth == null) {
          web.window.delete('innerWidth'.toJS);
        } else {
          _defineProperty(web.window, 'innerWidth'.toJS, originalWidth);
        }
      });
      await _resizeWindow(width);
      tester.pumpComponent(
        App(
          projectStore: MemoryProjectStore(),
          initialUri: Uri(
            queryParameters: {
              'embed': '$embed',
              'split': '$split',
              if (panelHints.isNotEmpty) 'panels': panelHints,
              if (files.isNotEmpty) 'file': files,
            },
          ),
          loadSource: (_) async => download != null
              ? download.future
              : contents({'lib/main.dart': 'void main() {}', 'README.md': '# Project'}),
          createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
              WorkspaceRepository(
                events: events,
                sdk: sdk,
                taskStatus: taskStatus,
                workspaceResourceApi: localApi!,
                workspaceFuture: Completer<Workspace>().future,
              ),
        ),
      );
      await pumpEventQueue();
      if (download == null) {
        expect(web.document.querySelector('.cm-editor'), isNotNull);
      }
    }

    SplitPanelState splitState(bool Function(SplitPanel) matches) {
      final element = find
          .byType(SplitPanel)
          .evaluate()
          .singleWhere(
            (element) => matches(element.component as SplitPanel),
          );
      return (element as StatefulElement).state as SplitPanelState;
    }

    SplitPanelState fileTreeSplit() => splitState((panel) => !panel.useRatio);
    SplitPanelState bottomSplit() => splitState((panel) => panel.isVertical);
    SplitPanelState previewSplit() => splitState((panel) => panel.useRatio && !panel.isVertical);

    Future<void> click(String selector) async {
      (web.document.querySelector(selector)! as web.HTMLButtonElement).click();
      await pumpEventQueue();
    }

    Future<void> selectOutputTab() => click('.small-screen-tab-bar-tab:nth-child(2)');
    Future<void> selectCodeTab() => click('.small-screen-tab-bar-tab:first-child');

    void expectConsoleSelected() {
      expect(web.document.querySelector('.console-panel'), isNotNull);
      expect(
        web.document.querySelector('.bottom-panel [role="tab"][aria-selected="true"]')!.textContent,
        startsWith('Console'),
      );
      expect(bottomSplit().state, const Split(0.6));
      final editorArea = web.document.querySelector('.editor-area')! as web.HTMLElement;
      expect(editorArea.style.flexGrow, '0.6');
    }

    for (final width in [600, 1200]) {
      for (final (embed, hint) in [(true, ''), (true, '-tabs'), (false, '-tabs')]) {
        testClient('single-file navigation follows open files: width=$width, embed=$embed, panels=$hint', (
          tester,
        ) async {
          await mountApp(tester, width: width, embed: embed, files: ['lib/main.dart'], panelHints: [hint]);
          expect(web.document.querySelector('button[aria-label="Show editor tabs"]'), isNull);
          expect(web.document.querySelector('button[aria-label="Collapse editor tabs"]'), isNull);
          expect(web.document.querySelector('.editor-tab-bar'), isNull);
          expect(web.document.querySelector('.editor-breadcrumbs'), isNull);

          final bottomPanel = find.byType(BottomPanel).evaluate().single.component as BottomPanel;
          bottomPanel.onOpenDiagnostic(
            'README.md',
            const Diagnostic(
              line: 0,
              character: 0,
              message: 'Project documentation',
              severity: DiagnosticSeverity.info,
            ),
          );
          await pumpEventQueue();

          expect(web.document.querySelector('button[aria-label="Show editor tabs"]'), isNull);
          expect(web.document.querySelector('button[aria-label="Collapse editor tabs"]'), isNull);
          expect(web.document.querySelector('.editor-tab-bar'), isNotNull);
          expect(web.document.querySelector('.editor-tab.active')!.getAttribute('title'), 'README.md');
          expect(web.document.querySelector('.editor-breadcrumbs')!.getAttribute('title'), 'README.md');
          expect(fileTreeSplit().state, embed ? const LeftHidden(200) : const Split(200));

          (web.document.querySelector('.editor-tab[title="lib/main.dart"]')! as web.HTMLElement).click();
          await pumpEventQueue();
          expect(web.document.querySelector('.editor-tab.active')!.getAttribute('title'), 'lib/main.dart');
          expect(web.document.querySelector('.editor-breadcrumbs')!.getAttribute('title'), 'lib/main.dart');

          await click('button[aria-label="Close README.md"]');
          expect(web.document.querySelector('button[aria-label="Show editor tabs"]'), isNull);
          expect(web.document.querySelector('button[aria-label="Collapse editor tabs"]'), isNull);
          expect(web.document.querySelector('.editor-tab-bar'), isNull);
          expect(web.document.querySelector('.editor-breadcrumbs'), isNull);
          expect(web.document.querySelector('.editor-tab-slot.active .cm-editor'), isNotNull);
          expect(fileTreeSplit().state, embed ? const LeftHidden(200) : const Split(200));
        });
      }

      for (final embed in [false, true]) {
        for (final files in [
          <String>[],
          ['lib/main.dart'],
          ['lib/main.dart', 'lib/main.dart'],
          ['lib/main.dart', 'README.md', 'lib/main.dart'],
        ]) {
          testClient('contextual navigation while loading and loaded: width=$width, embed=$embed, files=$files', (
            tester,
          ) async {
            final download = Completer<Project>();
            await mountApp(tester, width: width, embed: embed, files: files, download: download, split: 60);
            final showNavigation = !embed || files.toSet().length > 1;

            void expectLayout({required bool loaded}) {
              final tree = web.document.querySelector('.file-tree')! as web.HTMLElement;
              expect(tree.style.display, embed ? 'none' : '');
              expect(web.document.querySelector('.file-tree-rail'), isNull);
              expect(web.document.querySelector('.editor-tab-bar'), showNavigation ? isNotNull : isNull);
              expect(
                web.document.querySelector('.editor-breadcrumbs'),
                loaded && showNavigation ? isNotNull : isNull,
              );
              expect(web.document.querySelector('.app-bar'), embed ? isNull : isNotNull);
              expect(web.document.querySelector('.app-footer'), embed ? isNull : isNotNull);
              expect(web.document.querySelector('.bottom-panel.collapsed'), loaded && embed ? isNotNull : isNull);
              expect(web.document.querySelectorAll('.bottom-panel [role="tab"]').length, loaded ? 2 : 0);
              expect(fileTreeSplit().state, embed ? const LeftHidden(200) : const Split(200));
            }

            expectLayout(loaded: false);
            if (width == 1200) {
              expect(previewSplit().state, const Split(0.6));
            }
            download.complete(contents({'lib/main.dart': 'void main() {}', 'README.md': '# Project'}));
            await pumpEventQueue();
            expect(web.document.querySelector('.cm-editor'), isNotNull);
            expectLayout(loaded: true);
            await _resizeWindow(width == 1200 ? 600 : 1200);
            expectLayout(loaded: true);
            if (width == 600) {
              expect(previewSplit().state, const Split(0.6));
            }
          });
        }

        testClient('loading completion preserves panel interactions: width=$width, embed=$embed', (tester) async {
          final download = Completer<Project>();
          await mountApp(
            tester,
            width: width,
            embed: embed,
            download: download,
            split: 95,
            panelHints: ['-console,-problems,-preview,-filetree,-tabs,+appbar,+statusbar'],
          );
          final panels = (find.byType(EditorShell).evaluate().single.component as EditorShell).panelController;
          if (width == 1200) {
            final preview = find
                .byType(SplitPanel)
                .evaluate()
                .map((e) => e.component as SplitPanel)
                .singleWhere((panel) => panel.useRatio && !panel.isVertical);
            expect(preview.minValue, embed ? 0.05 : 0.3);
            expect(preview.maxValue, embed ? 0.95 : 0.85);
          }
          fileTreeSplit().split(235);
          panels.updatePreview(const RightCollapsed(0.62));
          await pumpEventQueue();
          bottomSplit().split(0.6);
          await pumpEventQueue();
          expect(bottomSplit().state, const Split(0.6));

          download.complete(contents({'lib/main.dart': 'void main() {}'}));
          await pumpEventQueue();
          expect(web.document.querySelector('.cm-editor'), isNotNull);
          expect(bottomSplit().state, const Split(0.6));
          expect(web.document.querySelector('.problems-panel'), isNotNull);
          await click('.bottom-panel [role="tab"]:nth-child(2)');
          expectConsoleSelected();
          expect(fileTreeSplit().state, const Split(235));
          expect(panels.preview, const RightCollapsed(0.62));
          expect(panels.appBar, PanelPresentationState.expanded);
          expect(panels.statusBar, PanelPresentationState.expanded);
          expect(panels.showEditorTabs, isFalse);
          expect(panels.showBreadcrumbs, isFalse);
          await _resizeWindow(width == 1200 ? 600 : 1200);
          expectConsoleSelected();
          expect(fileTreeSplit().state, const Split(235));
          expect(panels.preview, const RightCollapsed(0.62));
        });
      }
    }

    for (final width in [600, 1200]) {
      for (final embed in [false, true]) {
        testClient('negative panel hints apply before and after loading: width=$width, embed=$embed', (tester) async {
          final download = Completer<Project>();
          await mountApp(
            tester,
            width: width,
            embed: embed,
            download: download,
            split: 60,
            panelHints: ['-console,-problems,-preview,-tabs,-filetree,-appbar,-statusbar'],
          );
          final panels = (find.byType(EditorShell).evaluate().single.component as EditorShell).panelController;
          void expectLayout({required bool loaded}) {
            expect(panels.preview, embed ? const RightHidden(0.6) : const RightCollapsed(0.6));
            expect(fileTreeSplit().state, embed ? const LeftHidden(200) : const LeftCollapsed(200));
            expect(bottomSplit().state, embed ? const RightHidden(0.75) : const RightCollapsed(0.75));
            expect(web.document.querySelectorAll('.bottom-panel [role="tab"]').length, loaded && !embed ? 2 : 0);
            expect(web.document.querySelector('.editor-tab-bar'), isNull);
            expect(web.document.querySelector('.editor-breadcrumbs'), isNull);
            expect(web.document.querySelector('button[aria-label="Show editor tabs"]'), isNull);
            expect(web.document.querySelector('.app-bar'), isNull);
            expect(web.document.querySelector('.app-footer'), isNull);
          }

          expectLayout(loaded: false);
          download.complete(contents({'lib/main.dart': 'void main() {}'}));
          await pumpEventQueue();
          expectLayout(loaded: true);
          await _resizeWindow(width == 600 ? 1200 : 600);
          expectLayout(loaded: true);
          if (width == 1200) {
            expect(web.document.querySelector('.small-screen-tab-bar'), isNotNull);
            await selectOutputTab();
            expect(panels.preview, const Split(0.6));
            await selectCodeTab();
          }
        });

        testClient('positive panel hints override contextual defaults: width=$width, embed=$embed', (tester) async {
          await mountApp(
            tester,
            width: width,
            embed: embed,
            panelHints: ['+console,+preview,+tabs,+filetree,+appbar,+statusbar'],
          );
          expect(fileTreeSplit().state, const Split(200));
          expect(bottomSplit().state, const Split(0.75));
          expect(web.document.querySelectorAll('.bottom-panel [role="tab"]').length, 2);
          expect(web.document.querySelector('.console-panel'), isNotNull);
          expect(web.document.querySelector('.editor-tab-bar'), isNotNull);
          expect(web.document.querySelector('.editor-breadcrumbs'), isNotNull);
          expect(web.document.querySelector('.app-bar'), isNotNull);
          expect(web.document.querySelector('.app-footer'), isNotNull);
          if (width == 1200) {
            expect(previewSplit().state, const Split(0.7));
          }
        });

        for (final hint in ['-console', '-console,+problems', '+problems,-console']) {
          testClient('$hint always keeps both bottom tabs: width=$width, embed=$embed', (tester) async {
            await mountApp(tester, width: width, embed: embed, panelHints: [hint]);
            expect(web.document.querySelectorAll('.bottom-panel [role="tab"]').length, 2);
            final collapsed = embed && hint == '-console';
            expect(bottomSplit().state, collapsed ? const RightCollapsed(0.75) : const Split(0.75));
            expect(web.document.querySelector('.problems-panel'), collapsed ? isNull : isNotNull);
            if (!collapsed) {
              expect(
                web.document.querySelector('.bottom-panel [aria-selected="true"]')!.textContent,
                startsWith('Problems'),
              );
            }
          });
        }
      }
    }

    for (final width in [600, 1200]) {
      testClient('Run reveals a preview hidden by embed hints: width=$width', (tester) async {
        await mountApp(tester, width: width, files: ['lib/main.dart'], split: 60, panelHints: ['-preview']);
        final panels = (find.byType(EditorShell).evaluate().single.component as EditorShell).panelController;
        expect(panels.preview, const RightHidden(0.6));
        expect(web.document.querySelector('.small-screen-tab-bar'), width == 600 ? isNotNull : isNull);

        final run = web.document.querySelector('.main-editor-actions button')! as web.HTMLButtonElement;
        expect(run.disabled, isFalse);
        run.click();
        await pumpEventQueue();

        expect(panels.preview, const Split(0.6));
        final container = find.byType(PreviewContainer).evaluate().single.component as PreviewContainer;
        expect(container.preview.state, isA<PreviewStarting>());
        final preview = web.document.querySelector('.preview-container')! as web.HTMLElement;
        expect(preview.style.display, isNot('none'));
        expect(web.document.querySelector('.preview-container.collapsed'), isNull);
        if (width == 600) {
          expect(web.document.querySelector('.small-screen-tab-bar'), isNotNull);
          expect(web.document.querySelector('.editor-host'), isNull);
          await selectCodeTab();
          expect(web.document.querySelector('.cm-editor'), isNotNull);
        }
      });
    }

    testClient('mobile tabs allow switching with a preview hidden by embed hints', (tester) async {
      await mountApp(tester, width: 600, files: ['lib/main.dart'], split: 60, panelHints: ['-preview']);
      final panels = (find.byType(EditorShell).evaluate().single.component as EditorShell).panelController;
      expect(panels.preview, const RightHidden(0.6));
      expect(web.document.querySelector('.small-screen-tab-bar'), isNotNull);
      expect(web.document.querySelector('.cm-editor'), isNotNull);

      await selectOutputTab();
      expect(web.document.querySelector('.small-screen-tab-bar-tab.active')!.textContent, 'Output');
      expect(web.document.querySelector('.preview-container'), isNotNull);
      expect(web.document.querySelector('.editor-host'), isNull);

      // Mobile visibility follows the selected tab even if the desktop panel hides again.
      panels.updatePreview(const RightHidden(0.6));
      await pumpEventQueue();
      expect(web.document.querySelector('.small-screen-tab-bar'), isNotNull);
      expect(web.document.querySelector('.preview-container'), isNotNull);
      await selectCodeTab();
      expect(web.document.querySelector('.small-screen-tab-bar-tab.active')!.textContent, 'Code');
      expect(web.document.querySelector('.cm-editor'), isNotNull);
      expect(web.document.querySelector('.preview-container'), isNull);
    });

    testClient('mobile Output stays selected after desktop collapse and Run switches back from Code', (tester) async {
      await mountApp(tester, width: 600, files: ['lib/main.dart'], split: 60);
      await selectOutputTab();
      await _resizeWindow(1200);
      await click('button[aria-label="Hide preview"]');
      expect(previewSplit().state, const RightCollapsed(0.6));

      await _resizeWindow(600);
      expect(web.document.querySelector('.small-screen-tab-bar-tab.active')!.textContent, 'Output');
      expect(web.document.querySelector('.preview-container'), isNotNull);
      expect(web.document.querySelector('.editor-host'), isNull);

      await selectCodeTab();
      expect(web.document.querySelector('.cm-editor'), isNotNull);
      await click('.main-editor-actions button');
      expect(web.document.querySelector('.small-screen-tab-bar-tab.active')!.textContent, 'Output');
      expect(web.document.querySelector('.preview-container'), isNotNull);
      expect(web.document.querySelector('.editor-host'), isNull);
      final panels = (find.byType(EditorShell).evaluate().single.component as EditorShell).panelController;
      expect(panels.preview, const Split(0.6));
    });

    testClient('bars stay visible without toggle buttons across screen sizes', (tester) async {
      await mountApp(tester, width: 1200, embed: false);
      expect(web.document.querySelector('.app-bar'), isNotNull);
      expect(web.document.querySelector('.app-footer'), isNotNull);
      expect(web.document.querySelector('button[aria-label="Show app bar"]'), isNull);
      expect(web.document.querySelector('button[aria-label="Collapse app bar"]'), isNull);
      expect(web.document.querySelector('button[aria-label="Show status bar"]'), isNull);
      expect(web.document.querySelector('button[aria-label="Collapse status bar"]'), isNull);

      await _resizeWindow(600);
      expect(web.document.querySelector('.app-bar'), isNotNull);
      expect(web.document.querySelector('.app-footer'), isNotNull);
      expect(web.document.querySelector('.small-screen-tab-bar'), isNotNull);
      await selectOutputTab();
      expect(web.document.querySelector('.preview-container'), isNotNull);
      await selectCodeTab();
      expect(web.document.querySelector('.preview-container'), isNull);

      await _resizeWindow(1200);
      expect(web.document.querySelector('.app-bar'), isNotNull);
      expect(web.document.querySelector('.app-footer'), isNotNull);
    });

    testClient('negative bar hints leave small-screen navigation usable', (tester) async {
      await mountApp(tester, width: 600, embed: false, panelHints: ['-appbar,-statusbar,-tabs']);
      expect(web.document.querySelector('.panel-visibility'), isNull);
      expect(web.document.querySelector('.app-bar'), isNull);
      expect(web.document.querySelector('.app-footer'), isNull);
      await selectOutputTab();
      expect(web.document.querySelector('.preview-container'), isNotNull);
      await selectCodeTab();
      expect(web.document.querySelector('.cm-editor'), isNotNull);
    });

    testClient('embed defaults hide bars without reopen controls at every screen size', (tester) async {
      await mountApp(tester, width: 1200);
      expect(web.document.querySelector('#editor-navigation-panel'), isNull);
      expect(web.document.querySelector('.app-bar'), isNull);
      expect(web.document.querySelector('.app-footer'), isNull);
      await _resizeWindow(600);
      expect(web.document.querySelector('#editor-navigation-panel'), isNull);
      expect(web.document.querySelector('.small-screen-tab-bar'), isNotNull);
      await selectOutputTab();
      expect(web.document.querySelector('.preview-container'), isNotNull);
    });

    testClient('desktop panel sizes and Console selection survive a narrow layout and back', (tester) async {
      await mountApp(tester, width: 1200);
      fileTreeSplit().split(240);
      previewSplit().split(0.65);
      await pumpEventQueue();
      await click('.bottom-panel [role="tab"]:nth-child(2)');
      bottomSplit().split(0.6);
      await pumpEventQueue();
      await click('button[aria-label="Hide preview"]');
      expect(web.document.querySelector('.preview-container.collapsed'), isNotNull);

      await _resizeWindow(600);
      expect(web.document.querySelector('.small-screen-tab-bar'), isNotNull);
      expect(web.document.querySelector('.preview-container'), isNull);
      expect(fileTreeSplit().state, const Split(240));
      expect((web.document.querySelector('.file-tree')! as web.HTMLElement).style.flexBasis, '240px');
      expectConsoleSelected();

      await _resizeWindow(1200);
      expect(web.document.querySelector('.small-screen-tab-bar'), isNull);
      expect(web.document.querySelector('.preview-container.collapsed'), isNotNull);
      expect(previewSplit().state, const RightCollapsed(0.65));
      expect(fileTreeSplit().state, const Split(240));
      expectConsoleSelected();

      await click('button[aria-label="Show preview"]');
      final editorShell = web.document.querySelector('.editor-shell')! as web.HTMLElement;
      expect(editorShell.style.flexGrow, '0.65');
    });

    testClient('Code and Output retain collapsed panels, their sizes, and Console selection', (tester) async {
      await mountApp(tester, width: 600);
      fileTreeSplit().split(225);
      await pumpEventQueue();
      await click('button[aria-label="Hide file tree"]');
      await click('.bottom-panel [role="tab"]:nth-child(2)');
      bottomSplit().split(0.6);
      await pumpEventQueue();
      await click('button[aria-label="Hide bottom panel"]');

      await selectOutputTab();
      expect(web.document.querySelector('.preview-container'), isNotNull);
      expect(web.document.querySelector('.editor-host'), isNull);
      expect(web.document.querySelector('.bottom-panel'), isNull);

      await selectCodeTab();
      expect(web.document.querySelector('.preview-container'), isNull);
      expect(web.document.querySelector('.cm-editor'), isNotNull);
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);
      expect(fileTreeSplit().state, const LeftCollapsed(225));
      expect(web.document.querySelector('.bottom-panel.collapsed'), isNotNull);
      expect(web.document.querySelectorAll('.bottom-panel [role="tab"]').length, 2);
      expect(web.document.querySelector('.bottom-panel-content'), isNull);
      expect(bottomSplit().state, const RightCollapsed(0.6));

      // Reopen via the splitter, without changing the selected tab.
      bottomSplit().split();
      await pumpEventQueue();
      expectConsoleSelected();
      await click('button[aria-label="Show file tree"]');
      expect((web.document.querySelector('.file-tree')! as web.HTMLElement).style.flexBasis, '225px');
    });
  });

  for (final (embed, hint) in [(false, '-preview'), (true, '-preview'), (false, '')]) {
    testClient('automatic startup preserves preview layout: embed=$embed, panels=$hint', (tester) async {
      final worker = await DartPadSdk(assetBaseUrl: startupWorkerAssets).dedicatedWorker();
      addTearDown(worker.close);
      final workspace = await worker.createWorkspace();
      final readyWorkspace = Completer<Workspace>();
      var pendingRun = Completer<void>();
      tester.pumpComponent(
        App(
          projectStore: MemoryProjectStore(),
          initialUri: Uri.parse('?embed=$embed&sample_id=material.AppBar.1&panels=$hint'),
          loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
          createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
              WorkspaceRepository(
                events: events,
                sdk: sdk,
                taskStatus: taskStatus,
                workspaceResourceApi: localApi!,
                workspaceFuture: readyWorkspace.future,
                onFlush: () => pendingRun.future,
              ),
        ),
      );
      await pumpEventQueue();
      if (hint.isEmpty) {
        (web.document.querySelector('button[aria-label="Hide preview"]')! as web.HTMLButtonElement).click();
        await pumpEventQueue();
      }
      final shell = find.byType(EditorShell).evaluate().single.component as EditorShell;
      final panels = shell.panelController;
      final hiddenPreview = panels.preview;
      expect(hiddenPreview, embed ? isA<RightHidden>() : isA<RightCollapsed>());
      readyWorkspace.complete(workspace);
      await pumpEventQueue();
      final container = find.byType(PreviewContainer).evaluate().single.component as PreviewContainer;
      expect(container.preview.state, isA<PreviewStarting>());
      expect(panels.preview, hiddenPreview);

      await container.preview.stopCode();
      pendingRun.complete();
      pendingRun = Completer<void>();
      await pumpEventQueue();
      final run = web.document.querySelector('.main-editor-actions button')! as web.HTMLButtonElement;
      expect(run.disabled, isFalse);
      run.click();
      await pumpEventQueue();
      expect(container.preview.state, isA<PreviewStarting>());
      expect(panels.preview, isA<Split>());
    });
  }

  for (final (source, autoRunInEmbed) in [
    ('', false),
    ('sample=counter', false),
    ('sample=counter&run=true', false),
    ('sample=counter&run=false', false),
    ('sample_id=material.AppBar.0', false),
    ('sample_id=material.AppBar.1&run=true', true),
    ('sample_id=material.AppBar.2', false),
    ('sample_id=material.AppBar.3&run=true', false),
    ('sample_id=material.AppBar.1&run=false', true),
    ('sample_id=material.AppBar.3&run=false', false),
    ('sample_id=material.AppBar.1', true),
    ('sample_id=material.AppBar.1&run=anything', true),
    ('sample_id=material.AppBar.1&run=true&run=false', true),
    ('sample_id=material.AppBar', false),
    ('sample_id=material.ListTile.1', true),
    ('gist=abc&run=true', false),
    ('package=demo&run=true', false),
    ('url=https://example.com/project.tar.gz&run=true', false),
  ]) {
    for (final embed in [false, true]) {
      final autoRun = !embed || autoRunInEmbed;
      testClient('preview autorun=$autoRun with embed=$embed for $source', (tester) async {
        final worker = await DartPadSdk(assetBaseUrl: startupWorkerAssets).dedicatedWorker();
        addTearDown(worker.close);
        final workspace = await worker.createWorkspace();
        // Hold a started Run before it creates a sandbox or compiles code.
        final pendingRun = Completer<void>();
        tester.pumpComponent(
          App(
            projectStore: MemoryProjectStore(),
            initialUri: Uri.parse('/?embed=$embed&$source'),
            loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
            createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
                WorkspaceRepository(
                  events: events,
                  sdk: sdk,
                  taskStatus: taskStatus,
                  workspaceResourceApi: localApi!,
                  workspaceFuture: Future.value(workspace),
                  onFlush: () => pendingRun.future,
                ),
          ),
        );
        await pumpEventQueue();
        expect(web.document.querySelector('.cm-editor'), isNotNull);
        final container = find.byType(PreviewContainer).evaluate().single.component as PreviewContainer;
        expect(container.preview.state, autoRun ? isA<PreviewStarting>() : isA<PreviewInitial>());
        if (!autoRun) {
          (web.document.querySelector('button[aria-label="Hide preview"]')! as web.HTMLButtonElement).click();
          await pumpEventQueue();
          expect(web.document.querySelector('.preview-container.collapsed'), isNotNull);
          final run = web.document.querySelector('.main-editor-actions button')! as web.HTMLButtonElement;
          expect(run.disabled, isFalse);
          run.click();
          await pumpEventQueue();
          expect(container.preview.state, isA<PreviewStarting>());
          expect(web.document.querySelector('.preview-container.collapsed'), isNull);
        }
      });

      testClient('worker startup=$autoRun with embed=$embed for $source', (tester) async {
        final starts = <Completer<DartPad>>[];
        tester.pumpComponent(
          App(
            projectStore: MemoryProjectStore(),
            initialUri: Uri.parse('/?embed=$embed&$source'),
            loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
            createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
              expect(deferWorker, embed);
              return WorkspaceRepository.create(
                events: events,
                sdk: sdk,
                taskStatus: taskStatus,
                localApi: localApi,
                deferWorker: deferWorker,
                createWorker: () {
                  final start = Completer<DartPad>();
                  starts.add(start);
                  return start.future;
                },
              );
            },
          ),
        );
        await pumpEventQueue();
        expect(web.document.querySelector('.cm-editor'), isNotNull);
        expect(starts, hasLength(autoRun ? 1 : 0));
        if (!autoRun) {
          expect(web.document.querySelector('.preview iframe'), isNull);
          final run = web.document.querySelector('.main-editor-actions button')! as web.HTMLButtonElement;
          expect(run.disabled, isFalse);
          run.click();
          await pumpEventQueue();
          expect(starts, hasLength(1));
        }
      });
    }
  }

  for (final run in ['', '&run=false', '&run=true', '&run=anything', '&run=true&run=false']) {
    testClient('embed handshake injects without starting: $run', (tester) async {
      late WorkspaceRepository repository;
      final starts = <Completer<DartPad>>[];
      final originalName = web.window.name;
      web.window.name = 'flutter-docs-example';
      addTearDown(() => web.window.name = originalName);
      final readyMessages = <Object?>[];
      final subscription = web.EventStreamProviders.messageEvent.forTarget(web.window.parent).listen((event) {
        final data = event.data;
        if (data == null || !data.isA<JSObject>()) {
          return;
        }
        final message = data as JSObject;
        final type = message.getProperty<JSAny?>('type'.toJS)?.dartify();
        final sender = message.getProperty<JSAny?>('sender'.toJS)?.dartify();
        if (type == 'ready' && sender == web.window.name) {
          readyMessages.add({'type': type, 'sender': sender});
          injectSource("void main() { print('injected'); }");
        }
      });
      addTearDown(subscription.cancel);
      tester.pumpComponent(
        App(
          initialUri: Uri.parse('?embed=true&file=README.md$run'),
          loadSource: (_) async => contents({
            'README.md': '# Keep me',
            'lib/main.dart': 'void main() {}',
          }),
          createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
            return repository = WorkspaceRepository.create(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              localApi: localApi,
              deferWorker: deferWorker,
              createWorker: () {
                final start = Completer<DartPad>();
                starts.add(start);
                return start.future;
              },
            );
          },
        ),
      );
      await pumpEventQueue();
      expect(readyMessages, [
        {'sender': 'flutter-docs-example', 'type': 'ready'},
      ]);
      expect(
        web.document.querySelector('.editor-tab-slot.active .cm-content')!.textContent,
        contains("print('injected')"),
      );
      expect(await repository.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('injected')"));
      expect(await repository.workspaceResourceApi.readFileAsText('README.md'), '# Keep me');
      expect(starts, isEmpty);

      injectSource("void main() { print('updated'); }");
      await pumpEventQueue();
      expect(
        web.document.querySelector('.editor-tab-slot.active .cm-content')!.textContent,
        contains("print('updated')"),
      );
      expect(await repository.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('updated')"));
      expect(starts, isEmpty);
      expect(repository.hasRuntime, isFalse);
      expect(web.document.querySelector('.app-footer'), isNull);
      expect(web.document.querySelector('.preview iframe'), isNull);
    });
  }

  testClient('early embed messages survive asynchronous project loading', (tester) async {
    final download = Completer<Project>();
    tester.pumpComponent(
      App(
        initialUri: Uri.parse('?embed=true'),
        loadSource: (_) => download.future,
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
            WorkspaceRepository.create(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              localApi: localApi,
              deferWorker: deferWorker,
              createWorker: () => Completer<DartPad>().future,
            ),
      ),
    );
    injectSource("void main() { print('early'); }");
    download.complete(contents({'lib/main.dart': 'void main() {}'}));
    await pumpEventQueue();
    expect(web.document.querySelector('.cm-content')!.textContent, contains("print('early')"));
  });

  testClient('seven protocol embeds stay idle and coordinate after manual activation', (tester) async {
    final repositories = List<WorkspaceRepository?>.filled(7, null);
    final starts = List<int>.filled(7, 0);
    tester.pumpComponent(
      div([
        for (var i = 0; i < 7; i++)
          div(classes: 'protocol-$i', [
            App(
              initialUri: Uri.parse('?run=true&embed=true'),
              loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
              createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
                expect(deferWorker, isTrue);
                return repositories[i] = WorkspaceRepository.create(
                  events: events,
                  sdk: sdk,
                  taskStatus: taskStatus,
                  localApi: localApi,
                  deferWorker: deferWorker,
                  createWorker: () {
                    starts[i]++;
                    return Completer<DartPad>().future;
                  },
                );
              },
            ),
          ]),
      ]),
    );
    await pumpEventQueue();
    expect(web.document.querySelectorAll('.cm-editor').length, 7);
    expect(starts, everyElement(0));
    injectSource("void main() { print('injected'); }");
    await pumpEventQueue();
    for (final repository in repositories) {
      expect(await repository!.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('injected')"));
      expect(repository.hasRuntime, isFalse);
    }
    expect(starts, everyElement(0));
    expect(web.document.querySelector('.preview iframe'), isNull);

    Future<void> notifyStorage() async {
      // These app instances share a test window. Real sibling iframes receive
      // this notification from the browser when another frame writes storage.
      web.window.dispatchEvent(
        web.StorageEvent('storage', web.StorageEventInit(storageArea: web.window.localStorage)),
      );
      await pumpEventQueue();
    }

    for (var i = 0; i < 3; i++) {
      (web.document.querySelector('.protocol-$i .main-editor-actions button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      await notifyStorage();
    }
    expect(starts, [1, 1, 1, 0, 0, 0, 0]);
    expect(repositories.map((repository) => repository!.hasRuntime), [false, true, true, false, false, false, false]);
    expect(web.document.querySelector('.protocol-0 button[aria-label="Resume"]'), isNotNull);

    injectSource("void main() { print('updated while paused'); }");
    await pumpEventQueue();
    expect(starts, [1, 1, 1, 0, 0, 0, 0]);
    expect(repositories.first!.hasRuntime, isFalse);
    expect(web.document.querySelector('.protocol-0 button[aria-label="Resume"]'), isNotNull);
    expect(
      await repositories.first!.workspaceResourceApi.readFileAsText('lib/main.dart'),
      contains('updated while paused'),
    );

    (web.document.querySelector('.protocol-0 button[aria-label="Resume"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();
    await notifyStorage();
    expect(starts, [2, 1, 1, 0, 0, 0, 0]);
    expect(repositories.map((repository) => repository!.hasRuntime), [true, false, true, false, false, false, false]);
  });

  for (final query in ['', '?embed=false']) {
    testClient('without embed mode, protocol accepts code while the worker is starting: $query', (tester) async {
      final readyMessages = <Object?>[];
      final subscription = web.EventStreamProviders.messageEvent.forTarget(web.window.parent).listen((event) {
        final data = event.data;
        if (data == null || !data.isA<JSObject>()) {
          return;
        }
        final message = data as JSObject;
        final type = message.getProperty<JSAny?>('type'.toJS)?.dartify();
        final sender = message.getProperty<JSAny?>('sender'.toJS)?.dartify();
        if (type == 'ready' && sender == web.window.name) {
          readyMessages.add({'type': type, 'sender': sender});
          injectSource("void main() { print('injected'); }");
        }
      });
      addTearDown(subscription.cancel);
      late WorkspaceRepository repository;
      var starts = 0;
      tester.pumpComponent(
        App(
          initialUri: Uri.parse(query),
          projectStore: MemoryProjectStore(),
          loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
          createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
            expect(deferWorker, isFalse);
            return repository = WorkspaceRepository.create(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              localApi: localApi,
              deferWorker: deferWorker,
              createWorker: () {
                starts++;
                return Completer<DartPad>().future;
              },
            );
          },
        ),
      );
      await pumpEventQueue();
      expect(readyMessages, hasLength(1));
      expect(await repository.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('injected')"));
      expect(web.document.querySelector('.cm-content')!.textContent, contains("print('injected')"));

      injectSource("void main() { print('updated'); }");
      await pumpEventQueue();
      expect(readyMessages, hasLength(1));
      expect(starts, 1);
      expect(await repository.workspaceResourceApi.readFileAsText('lib/main.dart'), contains("print('updated')"));
      expect(web.document.querySelector('.cm-content')!.textContent, contains("print('updated')"));
      expect(web.document.querySelector('.app-footer'), isNotNull);
    });
  }

  testClient('embed Run lazily starts the runtime and can resume while retired startup is pending', (tester) async {
    late WorkspaceRepository repository;
    final starts = <Completer<DartPad>>[];
    tester.pumpComponent(
      App(
        initialUri: Uri.parse('/?sample_id=material.ListTile.3&run=false&embed=true'),
        loadSource: (_) async => contents({'lib/main.dart': 'void main() {}'}),
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
          expect(deferWorker, isTrue);
          return repository = WorkspaceRepository.create(
            events: events,
            sdk: sdk,
            taskStatus: taskStatus,
            localApi: localApi,
            deferWorker: deferWorker,
            createWorker: () {
              final start = Completer<DartPad>();
              starts.add(start);
              return start.future;
            },
          );
        },
      ),
    );
    await pumpEventQueue();
    expect(starts, isEmpty);
    final editor = web.document.querySelector('.cm-editor');
    expect(editor, isNotNull);
    final run = web.document.querySelector('.main-editor-actions button')! as web.HTMLButtonElement;
    run.click();
    await pumpEventQueue();
    expect(starts, hasLength(1));
    expect(repository.hasRuntime, isTrue);
    expect(web.document.querySelector('.cm-editor'), equals(editor));
    expect(run.disabled, isTrue);
    final firstKey = '${EmbedRuntimeController.storageKeyPrefix}other-a';
    final secondKey = '${EmbedRuntimeController.storageKeyPrefix}other-b';
    final timestamp = DateTime.now().millisecondsSinceEpoch + 100;
    web.window.localStorage.setItem(firstKey, jsonEncode({'lastSeen': timestamp}));
    web.window.localStorage.setItem(secondKey, jsonEncode({'lastSeen': timestamp + 1}));
    addTearDown(() {
      web.window.localStorage.removeItem(firstKey);
      web.window.localStorage.removeItem(secondKey);
    });
    web.window.dispatchEvent(
      web.StorageEvent(
        'storage',
        web.StorageEventInit(
          key: secondKey,
          storageArea: web.window.localStorage,
        ),
      ),
    );
    await pumpEventQueue();
    expect(repository.hasRuntime, isFalse);
    expect(web.document.querySelector('.cm-editor'), equals(editor));
    expect(run.disabled, isFalse);
    expect(web.document.body!.textContent, contains('LSP and Preview paused'));
    final resume = web.document.querySelector('button[aria-label="Resume"]')! as web.HTMLButtonElement;
    expect(resume.disabled, isFalse);
    resume.click();
    await pumpEventQueue();
    expect(starts, hasLength(2));
    expect(web.document.querySelector('button[aria-label="Resume"]'), isNull);
    starts.first.completeError(StateError('Retired startup failed'));
    await pumpEventQueue();
    expect(repository.hasRuntime, isTrue);
    expect(web.document.body!.textContent, isNot(contains('Retired startup failed')));
    expect(run.disabled, isTrue);
  });

  for (final source in ['sample=counter', 'sample_id=material.AppBar.1&channel=stable']) {
    for (final split in [5, 60, 95]) {
      testClient('embed layout and split=$split are source-independent for $source', (tester) async {
        tester.pumpComponent(
          App(
            projectStore: MemoryProjectStore(),
            initialUri: Uri.parse('/?$source&split=$split&embed=true'),
            loadSource: (_) async => contents({
              'lib/main.dart': "import 'package:flutter/material.dart'; void main() {}",
              'pubspec.yaml': 'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\n',
            }),
            createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
              expect(sdk.isFlutter, isTrue);
              expect(deferWorker, isTrue);
              return WorkspaceRepository(
                events: events,
                taskStatus: taskStatus,
                sdk: sdk,
                workspaceResourceApi: localApi!,
                // Keep automatic startup pending while checking the layout.
                workspaceFuture: Completer<Workspace>().future,
              );
            },
          ),
        );
        await pumpEventQueue();

        expect(web.document.querySelector('.app-bar'), isNull);
        expect(web.document.querySelector('.app-footer'), isNull);
        expect(web.document.querySelector('.file-tree-rail'), isNull);
        expect(web.document.querySelector('.editor-tab-bar'), isNull);
        expect(web.document.querySelector('.editor-breadcrumbs'), isNull);
        final editorShell = web.document.querySelector('.editor-shell')! as web.HTMLElement;
        expect(editorShell.style.flexGrow, (split / 100).toString());
      });
    }
  }

  for (final hasMain in [true, false]) {
    testClient('missing README opens main when available, hasMain=$hasMain', (tester) async {
      tester.pumpComponent(
        App(
          projectStore: MemoryProjectStore(),
          initialUri: Uri.parse('?sample=counter'),
          loadSource: (_) async => contents({if (hasMain) 'lib/main.dart': 'void main() {}'}),
          createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
              WorkspaceRepository(
                events: events,
                sdk: sdk,
                taskStatus: taskStatus,
                workspaceResourceApi: localApi!,
                workspaceFuture: Completer<Workspace>().future,
              ),
        ),
      );
      await pumpEventQueue();
      if (hasMain) {
        expect(web.document.querySelectorAll('.editor-tab').length, 1);
        expect(web.document.querySelector('.editor-tab.active .editor-tab-name')?.textContent, 'main.dart');
      } else {
        expect(web.document.querySelector('.editor-tab'), isNull);
      }
    });
  }

  for (final embed in [false, true]) {
    testClient('project load failures show an error dialog with recovery, embed=$embed', (tester) async {
      tester.pumpComponent(
        App(
          projectStore: MemoryProjectStore(),
          initialUri: Uri.parse('?sample=counter&embed=$embed'),
          loadSource: (_) async => throw const FormatException('Project download failed'),
        ),
      );
      await pumpEventQueue();
      expect(web.document.querySelector('[role="alertdialog"]')?.textContent, contains('Project download failed'));
      expect(web.document.querySelector('button[aria-label="Reload Page"]'), isNotNull);
      if (embed) {
        expect(web.document.querySelector('.app-bar'), isNull);
      }
      expect(web.document.querySelector('.editor-tab'), isNull);
    });
  }

  for (final initialSample in ['fibonacci', 'dart']) {
    testClient('opening Dart Snippet from $initialSample creates a fresh same-SDK worker', (tester) async {
      final originalUrl = web.window.location.href;
      addTearDown(() => web.window.history.replaceState(null, '', originalUrl));
      final repositories = <WorkspaceRepository>[];
      final workers = [await TestWorker.start(), await TestWorker.start()];
      for (final worker in workers) {
        addTearDown(worker.dispose);
      }
      var loads = 0;
      tester.pumpComponent(
        App(
          projectStore: MemoryProjectStore(),
          initialUri: Uri.parse('?sample=$initialSample'),
          loadSource: (_) async => contents({'lib/main.dart': 'void main() { print(${++loads}); }'}),
          createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
            final repository = WorkspaceRepository(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              workspaceResourceApi: localApi!,
              dartpad: workers[repositories.length].dartpad,
              workspaceFuture: Completer<Workspace>().future,
              readyWorkspaceFuture: Future.error(StateError('Test worker unavailable')),
            );
            repositories.add(repository);
            return repository;
          },
        ),
      );
      await pumpEventQueue();
      final old = repositories.single;
      expect(workers.first.isClosed, isFalse);
      (web.document.querySelector('button[aria-label="New"]')! as web.HTMLElement).click();
      await pumpEventQueue();
      final items = web.document.querySelectorAll('.dropdown-menu-item');
      final snippet = [
        for (var i = 0; i < items.length; i++) items.item(i)!,
      ].singleWhere((item) => item.textContent!.contains('Dart Snippet'));
      (snippet as web.HTMLElement).click();
      await pumpEventQueue();

      expect(loads, 2);
      expect(repositories, hasLength(2));
      final next = repositories.last;
      expect(next.sdk, old.sdk);
      expect(next.dartpad, isNot(same(old.dartpad)));
      expect(old.closeCount, 1);
      expect(workers.first.isClosed, isTrue);
      expect(next.closeCount, 0);
      expect(web.document.querySelector('.cm-content')!.textContent, contains('print(2)'));

      tester.binding.detachRootComponent();
      await pumpEventQueue();
      expect(old.closeCount, 1);
      expect(next.closeCount, 1);
      expect(workers.last.isClosed, isTrue);
    });
  }

  testClient('failed sample reset removes and disposes the old session', (tester) async {
    final originalUrl = web.window.location.href;
    addTearDown(() => web.window.history.replaceState(null, '', originalUrl));
    late WorkspaceRepository old;
    final worker = await TestWorker.start();
    addTearDown(worker.dispose);
    var loads = 0;
    tester.pumpComponent(
      App(
        projectStore: MemoryProjectStore(),
        initialUri: Uri.parse('?file=README.md'),
        loadSource: (_) async {
          if (++loads > 1) {
            throw const FormatException('New sample failed');
          }
          return contents({'README.md': '# Original project'});
        },
        createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) =>
            old = WorkspaceRepository(
              events: events,
              sdk: sdk,
              taskStatus: taskStatus,
              workspaceResourceApi: localApi!,
              dartpad: worker.dartpad,
              workspaceFuture: Completer<Workspace>().future,
              readyWorkspaceFuture: Future.error(StateError('Test worker unavailable')),
            ),
      ),
    );
    await pumpEventQueue();
    expect(web.document.querySelector('.editor-tab'), isNotNull);
    (web.document.querySelector('button[aria-label="New"]')! as web.HTMLElement).click();
    await pumpEventQueue();
    (web.document.querySelector('.dropdown-menu-item')! as web.HTMLElement).click();
    await pumpEventQueue();
    expect(loads, 2);
    expect(web.window.location.search, contains('sample='));
    expect(web.document.querySelector('.editor-tab'), isNull);
    expect(web.document.querySelector('[role="alertdialog"]')?.textContent, contains('New sample failed'));
    expect(old.closeCount, 1);
    expect(worker.isClosed, isTrue);
    expect(() => old.taskStatus.startTask(TaskKind.loadingCode), throwsStateError);
  });
}

void injectSource(String source) {
  web.window.dispatchEvent(
    web.MessageEvent(
      'message',
      web.MessageEventInit(
        source: web.window.parent,
        origin: 'https://docs.flutter.dev',
        data: {'type': 'sourceCode', 'sourceCode': source}.jsify(),
      ),
    ),
  );
}

// Headless Chrome cannot reliably resize the test iframe's native viewport.
// Override the browser input used by App and send its normal resize event.
Future<void> _resizeWindow(int width) async {
  _defineProperty(web.window, 'innerWidth'.toJS, {'configurable': true, 'value': width}.jsify() as JSObject);
  web.window.dispatchEvent(web.Event('resize'));
  await pumpEventQueue();
}

@JS('Object.defineProperty')
external void _defineProperty(JSObject target, JSString property, JSObject descriptor);

@JS('Object.getOwnPropertyDescriptor')
external JSObject? _getOwnPropertyDescriptor(JSObject target, JSString property);
