// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
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
    final sanitized = sanitizeHtml(markup, addLinkRel: (_) => ['noopener', 'noreferrer', 'nofollow', 'ugc']);
    container.textContent = '';
    for (final node in html_parser.parseFragment(sanitized).nodes) {
      container.appendChild(_buildNode(node));
    }
  }

  web.Node _buildNode(html.Node node) {
    if (node is html.Comment) {
      return web.document.createComment(node.data ?? '');
    }
    if (node is! html.Element) {
      return web.document.createTextNode(node.text ?? '');
    }
    final element = web.document.createElement(node.localName!);
    for (final attribute in node.attributes.entries) {
      // Picture sources need the same virtual filesystem support as images.
      if (attribute.key == 'srcset') {
        continue;
      }
      if (attribute.key == 'href' || attribute.key == 'src') {
        final uri = Uri.parse(attribute.value);
        // Project resources need the virtual filesystem. Until a resolver is
        // attached, never navigate to or request them from the DartPad server.
        if (!uri.hasScheme && !uri.hasAuthority) {
          continue;
        }
      }
      element.setAttribute(attribute.key as String, attribute.value);
    }
    for (final child in node.nodes) {
      element.appendChild(_buildNode(child));
    }
    if (node.localName == 'a') {
      element.setAttribute('target', '_blank');
      element.setAttribute('referrerpolicy', 'no-referrer');
    } else if (node.localName == 'img') {
      element.setAttribute('referrerpolicy', 'no-referrer');
      element.setAttribute('loading', 'lazy');
    }
    return element;
  }
}
