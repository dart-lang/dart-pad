// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:markdown/markdown.dart' as md;
import 'package:web/web.dart' as web;

/// Whether a file supports Markdown preview and editing.
bool isMarkdownFile(String path) {
  final lowerPath = path.toLowerCase();
  return lowerPath.endsWith('.md') || lowerPath.endsWith('.markdown');
}

/// Renders GitHub-flavored Markdown into a DOM node without a UI framework.
///
/// HTML comments are omitted, other raw HTML stays text, and URLs are restricted
/// to safe protocols, so project documentation cannot execute scripts in the
/// editor's browser context.
final class MarkdownRenderer {
  MarkdownRenderer({this.onOpenFile, this.loadImage}) : container = web.HTMLDivElement() {
    container.className = 'markdown-preview';
    container.setAttribute('role', 'document');
    container.setAttribute('aria-label', 'Markdown preview');
    container.tabIndex = 0;
  }

  final web.HTMLDivElement container;

  /// Opens a document-relative file in the host editor instead of the browser.
  final Future<void> Function(Uri uri)? onOpenFile;

  /// Resolves an image from the host's virtual filesystem to a display URL.
  ///
  /// Receives document-relative paths controlled by the Markdown author. The
  /// host must restrict which files it loads. Returned URLs bypass [_isSafeUrl]
  /// so this trusted loader can supply generated data or blob URLs; it must not
  /// return untrusted URLs without validating them itself.
  final Future<String?> Function(Uri uri)? loadImage;

  static int _nextId = 0;
  final String _idPrefix = 'markdown-${_nextId++}-';
  final Map<String, web.Element> _headingAnchors = {};
  String? _content;
  Uri? _documentUri;

  /// Updates the preview when its content or document URI changes.
  void render(String content, {Uri? documentUri}) {
    if (_content == content && _documentUri == documentUri) {
      return;
    }
    _content = content;
    _documentUri = documentUri;
    container.textContent = '';
    _headingAnchors.clear();
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubWeb,
      encodeHtml: false,
      blockSyntaxes: const [_HtmlBlockWithoutCommentsSyntax()],
      inlineSyntaxes: [_HtmlCommentSyntax()],
    );
    final nodes = document.parseLines(const LineSplitter().convert(content));
    for (final node in nodes) {
      container.appendChild(_buildNode(node));
    }
  }

  /// Reveals an anchor within this preview without navigating the host page.
  void scrollToFragment(String fragment) {
    if (fragment.isEmpty) {
      container.scrollTop = 0;
      return;
    }
    final heading = _headingAnchors[Uri.decodeComponent(fragment)];
    if (heading == null) {
      return;
    }
    // Scroll only the preview: scrollIntoView can move surrounding app panels.
    final top = heading.getBoundingClientRect().top - container.getBoundingClientRect().top + container.scrollTop;
    container.scrollTop = top;
  }

  web.Node _buildNode(md.Node node) {
    if (node is! md.Element) {
      return web.document.createTextNode(node.textContent);
    }
    final element = web.document.createElement(node.tag);
    for (final child in node.children ?? <md.Node>[]) {
      element.appendChild(_buildNode(child));
    }
    final attributes = node.attributes;
    if (attributes['title'] case final title?) {
      element.setAttribute('title', title);
    }
    if (attributes['href'] case final href? when node.tag == 'a' && _isSafeUrl(href)) {
      _configureLink(element, href);
    } else if (node.tag == 'img') {
      element.setAttribute('alt', attributes['alt'] ?? '');
      element.setAttribute('referrerpolicy', 'no-referrer');
      if (attributes['src'] case final src? when _isSafeUrl(src, image: true)) {
        final uri = Uri.parse(src);
        if (_isDocumentRelative(uri)) {
          if (_documentUri case final documentUri?) {
            unawaited(_loadImage(element, documentUri.resolveUri(uri)));
          }
        } else {
          element.setAttribute('src', src);
        }
        element.setAttribute('loading', 'lazy');
      }
    } else if (node.tag == 'input') {
      element.setAttribute('type', 'checkbox');
      element.setAttribute('disabled', '');
      if (attributes.containsKey('checked')) {
        element.setAttribute('checked', '');
      }
    } else if (attributes['start'] case final start? when node.tag == 'ol') {
      element.setAttribute('start', start);
    }
    if (node.generatedId case final id?) {
      _setScrollingAnchorId(element, id);
    }
    return element;
  }

  void _setScrollingAnchorId(web.Element element, String id) {
    var uniqueId = id;
    var suffix = 1;
    while (_headingAnchors.containsKey(uniqueId)) {
      uniqueId = '$id-${suffix++}';
    }
    _headingAnchors[uniqueId] = element;
    element.setAttribute('id', '$_idPrefix$uniqueId');
  }

  bool _isDocumentRelative(Uri uri) => !uri.hasScheme && !uri.hasAuthority;

  void _configureLink(web.Element link, String href) {
    final uri = Uri.parse(href);
    if (href.startsWith('#')) {
      link.setAttribute('href', Uri(fragment: '$_idPrefix${Uri.decodeComponent(uri.fragment)}').toString());
      link.addEventListener(
        'click',
        ((web.Event event) {
          event.preventDefault();
          scrollToFragment(uri.fragment);
        }).toJS,
      );
      return;
    }
    if (_isDocumentRelative(uri)) {
      final documentUri = _documentUri;
      final openFile = onOpenFile;
      if (documentUri == null || openFile == null) {
        return;
      }
      final target = documentUri.resolveUri(uri);
      link.setAttribute('href', target.toString());
      link.addEventListener(
        'click',
        ((web.Event event) {
          event.preventDefault();
          unawaited(openFile(target));
        }).toJS,
      );
      return;
    }
    link.setAttribute('href', href);
    link.setAttribute('target', '_blank');
    link.setAttribute('rel', 'noopener noreferrer nofollow ugc');
    link.setAttribute('referrerpolicy', 'no-referrer');
  }

  Future<void> _loadImage(web.Element image, Uri uri) async {
    try {
      final url = await loadImage?.call(uri);
      // A content edit or rename may replace the image while its bytes load.
      if (url != null && container.contains(image)) {
        image.setAttribute('src', url);
      }
    } catch (_) {
      // Missing or unsupported images retain their alt text, without requesting
      // an unrelated resource from the DartPad web server.
    }
  }

  bool _isSafeUrl(String value, {bool image = false}) {
    const asciiSpace = 0x20;
    const asciiDelete = 0x7f;
    // Reject ASCII controls (below space), spaces, and DEL before parsing:
    // browsers can normalize whitespace and control characters in URLs.
    if (value.codeUnits.any((codeUnit) => codeUnit <= asciiSpace || codeUnit == asciiDelete)) {
      return false;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return false;
    }
    return !uri.hasScheme || const {'http', 'https'}.contains(uri.scheme) || (!image && uri.scheme == 'mailto');
  }
}

/// Omits comments during inline parsing, after code spans and escapes have
/// consumed their literal content.
final class _HtmlCommentSyntax extends md.InlineSyntax {
  _HtmlCommentSyntax() : super(r'<!--[\s\S]*?-->', startCharacter: '<'.codeUnitAt(0));

  @override
  bool onMatch(md.InlineParser parser, Match match) => true;
}

/// HTML blocks bypass inline parsing, so their comments need separate handling.
final class _HtmlBlockWithoutCommentsSyntax extends md.HtmlBlockSyntax {
  const _HtmlBlockWithoutCommentsSyntax();

  // Match whole HTML tags too, keeping comment-like text in quoted attributes.
  // An unclosed block comment extends to the end of its parsed HTML block.
  static final _htmlTokens = RegExp(
    r'<!--[\s\S]*?(?:-->|$)|' + md.InlineHtmlSyntax().pattern.pattern,
  );

  @override
  md.Node parse(md.BlockParser parser) {
    final text = super.parse(parser).textContent;
    return md.Text(
      text.replaceAllMapped(_htmlTokens, (match) {
        final token = match[0]!;
        return token.startsWith('<!--') ? '' : token;
      }),
    );
  }
}
