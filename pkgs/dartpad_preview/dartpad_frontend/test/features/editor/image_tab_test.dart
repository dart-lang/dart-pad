// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/editor/components/image_preview.dart';
import 'package:dartpad_frontend/features/editor/image/image_tab.dart';
import 'package:dartpad_frontend/features/shared/editable_text_file.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

final class _Workspace implements WorkspaceResourceApi {
  _Workspace(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> readFileAsBytes(String uri) async => bytes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const supportedFormats = {
    'logo.png': 'image/png',
    'logo.JPG': 'image/jpeg',
    'logo.Jpeg': 'image/jpeg',
    'logo.gif': 'image/gif',
    'logo.ICO': 'image/x-icon',
    'logo.svg': 'image/svg+xml',
    'logo.webp': 'image/webp',
  };

  test('recognizes exactly the supported image formats case-insensitively', () {
    expect(
      supportedImageExtensions,
      supportedFormats.keys.map((path) => path.substring(path.lastIndexOf('.')).toLowerCase()).toSet(),
    );

    for (final entry in supportedFormats.entries) {
      expect(isPreviewableImageFile(entry.key), isTrue, reason: entry.key);
      expect(isSupportedFile(entry.key), isTrue, reason: entry.key);
      expect(imageMimeTypeForPath(entry.key), entry.value);
    }

    for (final path in ['logo.bmp', 'logo.avif', 'logo.pdf']) {
      expect(isPreviewableImageFile(path), isFalse, reason: path);
      expect(isSupportedFile(path), isFalse, reason: path);
      expect(imageMimeTypeForPath(path), isNull);
    }
  });

  test('image tab adapter creates read-only tabs only for supported images', () async {
    final workspace = _Workspace(Uint8List(0));
    final adapter = ImageTabAdapter(workspaceResourceApi: workspace);

    for (final path in supportedFormats.keys) {
      final tab = await adapter.createTab(path);
      expect(tab, isA<ImageTab>(), reason: path);
      expect(tab!.hasUnsavedChanges, isFalse);
      expect(tab.build(), isA<ImagePreview>());
    }

    expect(await adapter.createTab('logo.bmp'), isNull);
    expect(await adapter.createTab('logo.avif'), isNull);
  });

  testClient('renders workspace bytes as a MIME-correct data URL', (tester) async {
    tester.pumpComponent(
      ImagePreview(
        path: 'assets/logo.svg',
        workspaceResourceApi: _Workspace(Uint8List.fromList('<svg/>'.codeUnits)),
      ),
    );
    await pumpEventQueue();

    final image = web.document.querySelector('.image-preview-element')!;
    expect(image.getAttribute('src'), 'data:image/svg+xml;base64,PHN2Zy8+');
  });
}
