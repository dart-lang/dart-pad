// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/editable_text_file.dart';

/// Renders an image file from the current workspace inside an editor tab.
final class ImagePreview extends StatefulComponent {
  /// Creates an image preview for [path].
  const ImagePreview({
    required this.path,
    required this.workspaceResourceApi,
    super.key,
  });

  /// The workspace-relative image path.
  final String path;

  /// Source of the image bytes.
  final WorkspaceResourceApi workspaceResourceApi;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();

  @css
  static List<StyleRule> get styles => _ImagePreviewState.styles;
}

final class _ImagePreviewState extends State<ImagePreview> {
  String? _dataUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateComponent(ImagePreview oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.path != component.path) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _dataUrl = null;
      _error = null;
    });

    try {
      final bytes = await component.workspaceResourceApi.readFileAsBytes(component.path);
      final mimeType = imageMimeTypeForPath(component.path);
      if (mimeType == null) {
        throw UnsupportedError('Unsupported image format.');
      }
      setState(() {
        _dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load image.';
      });
    }
  }

  @override
  Component build(BuildContext context) {
    if (_error != null) {
      return div(classes: 'image-preview-status error', [Component.text(_error!)]);
    }
    if (_dataUrl == null) {
      return const div(classes: 'image-preview-status', [Component.text('Loading image...')]);
    }
    return div(classes: 'image-preview-container', [
      img(src: _dataUrl!, classes: 'image-preview-element'),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.image-preview-container').styles(
      display: .flex,
      width: 100.percent,
      height: 100.percent,
      padding: .all(20.px),
      boxSizing: .borderBox,
      overflow: const .only(x: .auto, y: .auto),
      justifyContent: .center,
      alignItems: .center,
      backgroundColor: const Color('#1e1e1e'),
    ),
    css('.image-preview-element').styles(
      maxWidth: 100.percent,
      maxHeight: 100.percent,
      radius: .all(Radius.circular(4.px)),
      shadow: BoxShadow(
        offsetX: 0.px,
        offsetY: 4.px,
        blur: 12.px,
        color: const Color.rgba(0, 0, 0, 0.15),
      ),
      raw: {'object-fit': 'contain'},
    ),
    css('.image-preview-status').styles(
      display: .flex,
      width: 100.percent,
      height: 100.percent,
      justifyContent: .center,
      alignItems: .center,
      color: const Color('#a8a8a8'),
      fontSize: 14.px,
    ),
    css('.image-preview-status.error').styles(color: const Color('#ff8a8a')),
  ];
}
