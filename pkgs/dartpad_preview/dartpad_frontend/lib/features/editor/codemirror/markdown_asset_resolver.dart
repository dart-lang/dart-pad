// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/app_event_bus.dart';
import '../../shared/events/error_toast_event.dart';
import '../../shared/supported_file_types.dart';
import 'code_mirror_tab.dart';

/// Resolves Markdown links and images against the editor's virtual filesystems.
///
/// The tab lookup keeps callbacks inactive after the owning adapter is disposed.
final class MarkdownAssetResolver {
  MarkdownAssetResolver({required this.origin, required this.getTabs, this.readSystemFileAsBytes, this.events});

  final EditorTabOrigin origin;
  final TabsController<Component>? Function() getTabs;
  final Future<Uint8List> Function(Uri uri)? readSystemFileAsBytes;
  final AppEventBus? events;

  Future<void> openLink(Uri uri) async {
    try {
      final asset = _resolve(uri);
      if (asset == null) {
        return;
      }
      await asset.open();
      if (getTabs()?.activeTab case final CodeMirrorTab tab when uri.hasFragment) {
        tab.revealMarkdownFragment(uri.fragment);
      }
    } on TabOpenCancelledException {
      // Closing the workspace while a linked file loads cancels navigation.
    } catch (_) {
      events?.dispatch(const ErrorToastEvent('Could not open linked file.'));
    }
  }

  Future<String?> loadImage(Uri uri) async {
    final asset = _resolve(uri);
    if (asset == null) {
      return null;
    }
    final mimeType = imageMimeTypeForPath(asset.path);
    final reader = asset.readBytes;
    if (mimeType == null || reader == null) {
      return null;
    }
    final bytes = await reader();
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  ({String path, Future<void> Function() open, Future<Uint8List> Function()? readBytes})? _resolve(Uri uri) {
    final tabs = getTabs();
    if (tabs == null) {
      return null;
    }
    switch (origin) {
      case EditorTabOrigin.workspace:
        final path = workspacePathFromUri(uri);
        if (path == null) {
          return null;
        }
        return (
          path: path,
          open: () => tabs.openWorkspaceFile(path),
          readBytes: () => tabs.workspaceResourceApi.readFileAsBytes(path),
        );
      case EditorTabOrigin.system:
        if (!uri.hasScheme) {
          return null;
        }
        // The worker addresses files by path, without URL queries or anchors.
        final fileUri = uri.resolve(uri.path);
        final reader = readSystemFileAsBytes;
        return (
          path: Uri.decodeComponent(fileUri.path),
          open: () => tabs.openSystemFile(fileUri),
          readBytes: reader == null ? null : () => reader(fileUri),
        );
    }
  }
}
