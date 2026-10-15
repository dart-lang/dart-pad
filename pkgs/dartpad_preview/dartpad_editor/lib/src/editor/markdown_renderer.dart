// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;
import 'package:sanitize_html/sanitize_html.dart';
import 'package:web/web.dart' as web;

import '../workspace/workspace_path.dart';

/// Whether a file supports Markdown preview and editing.
bool isMarkdownFile(String path) {
  final lowerPath = path.toLowerCase();
  return lowerPath.endsWith('.md') || lowerPath.endsWith('.markdown');
}

/// Renders sanitized GitHub-flavored Markdown into an editor preview.
final class MarkdownRenderer {
  MarkdownRenderer({this.onOpenFile, this.loadImage}) : container = web.HTMLDivElement() {
    container.className = 'markdown-preview';
    container.setAttribute('role', 'document');
    container.setAttribute('aria-label', 'Markdown preview');
    container.tabIndex = 0;
  }

  final web.HTMLDivElement container;

  /// Opens a document-relative file in the host editor.
  final Future<void> Function(Uri uri)? onOpenFile;

  /// Loads a resolved image from the virtual filesystem.
  ///
  /// The loader must validate access to the author-selected path. Its returned
  /// URL bypasses sanitization so it may supply generated data or blob URLs;
  /// it must generate that URL itself or validate any untrusted URL it returns.
  final Future<String?> Function(Uri uri)? loadImage;

  String? _content;
  Uri? _documentUri;

  /// Updates the preview when its content or document URI changes.
  void render(String content, {Uri? documentUri}) {
    if (_content == content && _documentUri == documentUri) {
      return;
    }
    _content = content;
    _documentUri = documentUri;
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
        // Resolve project resources before assigning browser destinations.
        if (isDocumentRelativeUri(uri)) {
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
      if (node.attributes['href'] case final href?) {
        final uri = Uri.parse(href);
        // Heading navigation is separate from opening a linked project file.
        if (isDocumentRelativeUri(uri) && !href.startsWith('#')) {
          final documentUri = _documentUri;
          final openFile = onOpenFile;
          if (documentUri != null && openFile != null) {
            final target = documentUri.resolveUri(uri);
            element.setAttribute('href', target.toString());
            element.addEventListener(
              'click',
              ((web.Event event) {
                event.preventDefault();
                unawaited(openFile(target));
              }).toJS,
            );
          }
        }
      }
    } else if (node.localName == 'img') {
      element.setAttribute('referrerpolicy', 'no-referrer');
      element.setAttribute('loading', 'lazy');
      if (node.attributes['src'] case final src?) {
        final uri = Uri.parse(src);
        if (isDocumentRelativeUri(uri)) {
          if (_documentUri case final documentUri?) {
            unawaited(_loadImage(element, documentUri.resolveUri(uri)));
          }
        }
      }
    }
    return element;
  }

  Future<void> _loadImage(web.Element image, Uri uri) async {
    try {
      final url = await loadImage?.call(uri);
      // A content edit or rename may replace the image while its bytes load.
      if (url != null && container.contains(image)) {
        image.setAttribute('src', url);
      }
    } catch (_) {
      // Missing images keep their alt text without requesting the web server.
    }
  }
}
