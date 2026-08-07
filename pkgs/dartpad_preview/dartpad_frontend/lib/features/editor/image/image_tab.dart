// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/editable_text_file.dart';
import '../components/image_preview.dart';

/// A read-only editor tab that displays a workspace image.
final class ImageTab extends EditorTab<Component> {
  /// Creates an image tab backed by [workspaceResourceApi].
  ImageTab(super.path, {required this.workspaceResourceApi});

  final WorkspaceResourceApi workspaceResourceApi;

  @override
  Component build() => ImagePreview(
    path: path,
    workspaceResourceApi: workspaceResourceApi,
  );
}

/// Creates [ImageTab] instances for image files supported by the browser preview.
final class ImageTabAdapter extends EditorTabAdapter<Component> {
  /// Creates an adapter using [workspaceResourceApi] for each image tab.
  const ImageTabAdapter({required this.workspaceResourceApi});

  final WorkspaceResourceApi workspaceResourceApi;

  @override
  Future<EditorTab<Component>?> createTab(String path) async {
    if (!isPreviewableImageFile(path)) {
      return null;
    }
    return ImageTab(path, workspaceResourceApi: workspaceResourceApi);
  }
}
