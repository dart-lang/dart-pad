// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../shared/app_event_bus.dart';
import '../../shared/components/context_menu.dart';
import '../../shared/events/error_toast_event.dart';
import '../../shared/supported_file_types.dart';
import 'code_mirror_tab.dart';

/// Creates text tabs and synchronizes them with workspace and LSP changes.
final class CodeMirrorTabAdapter extends EditorTabAdapter<Component> {
  /// Creates an adapter for files using the codemirror editor.
  CodeMirrorTabAdapter({
    this.contextMenu,
    this.events,
    this.onRun,
    this.readSystemFile,
    this.readSystemFileAsBytes,
  });

  final ContextMenuController? contextMenu;
  final AppEventBus? events;
  final void Function()? onRun;

  /// Reads URI-addressed files that are outside the project workspace.
  final Future<String> Function(Uri uri)? readSystemFile;

  /// Reads image bytes from SDK and pub-cache files in the worker.
  final Future<Uint8List> Function(Uri uri)? readSystemFileAsBytes;

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
  Future<EditorTab<Component>?> createWorkspaceTab(String path) async {
    final tabs = _tabs;
    if (tabs == null) {
      return null;
    }
    if (!isTextFile(path)) {
      return null;
    }
    final content = await tabs.workspaceResourceApi.root.getFile(path).readContent();
    return WorkspaceCodeMirrorTab(
      path: path,
      content: content,
      onSaveAll: _saveAll,
      onRun: onRun,
      workspaceResourceApi: tabs.workspaceResourceApi,
      languageServerClient: _languageServerClient,
      contextMenu: contextMenu,
      events: events,
      onOpenMarkdownFile: _openMarkdownFile,
      loadMarkdownImage: _loadWorkspaceMarkdownImage,
    );
  }

  @override
  Future<EditorTab<Component>?> createSystemTab(Uri uri) async {
    final reader = readSystemFile;
    if (_tabs == null || reader == null || !isTextFile(uri.path)) {
      return null;
    }
    return SystemCodeMirrorTab(
      uri: uri,
      content: await reader(uri),
      onRun: onRun,
      languageServerClient: _languageServerClient,
      onOpenMarkdownFile: _openMarkdownFile,
      loadMarkdownImage: _loadSystemMarkdownImage,
    );
  }

  Future<void> _openMarkdownFile(Uri uri) async {
    final tabs = _tabs;
    if (tabs == null) {
      return;
    }
    try {
      if (!uri.hasScheme) {
        final path = _workspaceMarkdownPath(uri);
        if (path == null) {
          return;
        }
        await tabs.openWorkspaceFile(path);
      } else {
        // The worker addresses files by path, without URL queries or anchors.
        await tabs.openSystemFile(uri.resolve(uri.path));
      }
      if (tabs.activeTab case final CodeMirrorTab tab when uri.hasFragment) {
        tab.revealMarkdownFragment(uri.fragment);
      }
    } on TabOpenCancelledException {
      // Closing the workspace while a linked file loads cancels navigation.
    } catch (_) {
      events?.dispatch(const ErrorToastEvent('Could not open linked file.'));
    }
  }

  Future<String?> _loadWorkspaceMarkdownImage(Uri uri) async {
    final path = _workspaceMarkdownPath(uri);
    final mimeType = path == null ? null : imageMimeTypeForPath(path);
    final tabs = _tabs;
    if (path == null || mimeType == null || tabs == null) {
      return null;
    }
    final bytes = await tabs.workspaceResourceApi.readFileAsBytes(path);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  Future<String?> _loadSystemMarkdownImage(Uri uri) async {
    final mimeType = imageMimeTypeForPath(Uri.decodeComponent(uri.path));
    final reader = readSystemFileAsBytes;
    if (mimeType == null || reader == null || _tabs == null) {
      return null;
    }
    final bytes = await reader(uri.resolve(uri.path));
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String? _workspaceMarkdownPath(Uri uri) {
    if (uri.hasScheme || uri.hasAuthority || !uri.path.startsWith('/')) {
      return null;
    }
    final path = normalizeWorkspacePath(Uri.decodeComponent(uri.path).substring(1));
    return isWithinWorkspaceFolder(path, '') ? path : null;
  }

  void _saveAll() {
    final tabs = _tabs;
    if (tabs != null) {
      unawaited(tabs.saveAllTabs().catchError((_) {}));
    }
  }

  void attachLanguageServerClient(LanguageServerClient? languageServerClient) {
    if (identical(_languageServerClient, languageServerClient)) {
      return;
    }
    _languageServerClient = languageServerClient;
    _analysisSubscription?.cancel();
    _analysisSubscription = languageServerClient?.codeMirrorLspClient.analysisStatus.listen((isAnalyzing) {
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
