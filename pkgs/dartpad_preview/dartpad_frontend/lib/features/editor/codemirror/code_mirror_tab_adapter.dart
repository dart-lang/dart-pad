// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import 'code_mirror_tab.dart';

/// Creates text tabs and synchronizes them with workspace and LSP changes.
final class CodeMirrorTabAdapter extends EditorTabAdapter<Component> {
  /// Creates an adapter for files using the codemirror editor.
  CodeMirrorTabAdapter();

  TabsController<Component>? _tabs;
  LanguageServerClient? _languageServerClient;
  StreamSubscription<bool>? _analysisSubscription;
  StreamSubscription<web.MouseEvent>? _tooltipSubscription;

  @override
  void register(TabsController<Component> tabs) {
    _tabs = tabs;

    _tooltipSubscription = web.EventStreamProviders.mouseDownEvent.forTarget(web.document).listen((event) {
      final target = event.target;
      if (target != null && target.isA<web.Element>()) {
        final element = target as web.Element;
        if (element.closest('.cm-tooltip') != null) {
          return;
        }
      }
      CodeMirrorEditor.hideAllTooltips();
    });
  }

  @override
  Future<EditorTab<Component>?> createTab(String path) async {
    final tabs = _tabs;
    if (tabs == null) {
      return null;
    }
    final content = await tabs.workspaceResourceApi.root.getFile(path).readContent();
    return CodeMirrorTab(
      path: path,
      content: content,
      onSaveAll: _saveAll,
      workspaceResourceApi: tabs.workspaceResourceApi,
      languageServerClient: _languageServerClient,
    );
  }

  void _saveAll() {
    final tabs = _tabs;
    if (tabs != null) {
      unawaited(tabs.saveAllTabs().catchError((_) {}));
    }
  }

  void attachLanguageServerClient(LanguageServerClient languageServerClient) {
    if (identical(_languageServerClient, languageServerClient)) {
      return;
    }
    _languageServerClient = languageServerClient;
    _analysisSubscription?.cancel();
    _analysisSubscription = languageServerClient.codeMirrorLspClient.analysisStatus.listen((isAnalyzing) {
      if (isAnalyzing) {
        return;
      }
      final tab = _tabs?.activeTab;
      if (tab case CodeMirrorTab(:final container, :final editor) when container.isConnected) {
        editor.triggerLspRefresh();
      }
    });

    if (_tabs?.allTabs case final allTabs?) {
      for (final tab in allTabs) {
        if (tab is CodeMirrorTab) {
          tab.editor.attachLanguageServerClient(languageServerClient);
        }
      }
    }
  }

  @override
  void dispose() {
    unawaited(_analysisSubscription?.cancel());
    unawaited(_tooltipSubscription?.cancel());
    _analysisSubscription = null;
    _tooltipSubscription = null;
    _tabs = null;
  }
}
