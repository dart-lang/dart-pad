// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart' as md;
import 'package:sanitize_html/sanitize_html.dart';

/// Whether a file supports Markdown preview and editing.
bool isMarkdownFile(String path) {
  final lowerPath = path.toLowerCase();
  return lowerPath.endsWith('.md') || lowerPath.endsWith('.markdown');
}

/// Converts GitHub-flavored Markdown to sanitized HTML.
///
/// The returned HTML is safe to insert into a preview container. Code blocks
/// are rendered as plain text; syntax highlighting requires a separate highlighter.
String renderMarkdown(String content) {
  final markup = md.markdownToHtml(content, extensionSet: md.ExtensionSet.gitHubWeb);
  return sanitizeHtml(markup);
}
