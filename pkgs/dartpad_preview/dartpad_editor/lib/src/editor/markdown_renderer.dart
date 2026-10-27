// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';

import 'package:markdown/markdown.dart' as md;
import 'package:sanitize_html/sanitize_html.dart';
import 'package:web/web.dart' as web;

/// Whether a file supports Markdown preview and editing.
bool isMarkdownFile(String path) {
  final lowerPath = path.toLowerCase();
  return lowerPath.endsWith('.md') || lowerPath.endsWith('.markdown');
}

/// Renders sanitized GitHub-flavored Markdown into an editor preview.
final class MarkdownRenderer {
  MarkdownRenderer() : container = web.HTMLDivElement() {
    container.className = 'markdown-preview';
    container.setAttribute('role', 'document');
    container.setAttribute('aria-label', 'Markdown preview');
    container.tabIndex = 0;
  }

  final web.HTMLDivElement container;
  String? _content;

  /// Updates the preview when its content changes.
  void render(String content) {
    if (_content == content) {
      return;
    }
    _content = content;
    final markup = md.markdownToHtml(content, extensionSet: md.ExtensionSet.gitHubWeb);
    final sanitized = sanitizeHtml(markup);
    container.innerHTML = sanitized.toJS;
  }
}
