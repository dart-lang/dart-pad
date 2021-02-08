// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.documentation;

import 'dart:convert' as convert show htmlEscape;
import 'dart:html';
import 'dart:math' as math;

import 'package:markdown/markdown.dart' as markdown;

import 'context.dart';
import 'dart_pad.dart';
import 'editing/editor.dart';
import 'services/common.dart';
import 'services/dartservices.dart';
import 'src/util.dart';

class DocHandler {
  static const Set<int> cursorKeys = {
    KeyCode.LEFT,
    KeyCode.RIGHT,
    KeyCode.UP,
    KeyCode.DOWN
  };

  final Editor _editor;
  final Context _context;

  final NodeValidator _htmlValidator = PermissiveNodeValidator();

  int /*?*/ _previousDocHash;

  DocHandler(this._editor, this._context);

  void generateDoc(List<DivElement> docElements) {
    if (docElements.isEmpty) {
      return;
    }

    if (_context.focusedEditor != 'dart') {
      _previousDocHash = null;
      for (final docPanel in docElements) {
        docPanel.innerHtml = '';
      }
      return;
    }
    if (!_editor.hasFocus || _editor.document.selection.isNotEmpty) {
      return;
    }

    final offset = _editor.document.indexFromPos(_editor.document.cursor);

    final request = SourceRequest()..offset = offset;

    if (_editor.completionActive) {
      // If the completion popup is open we create a new source as if the
      // completion popup was chosen, and ask for the documentation of that
      // source.
      request.source =
          _sourceWithCompletionInserted(_context.dartSource, offset);
    } else {
      request.source = _context.dartSource;
    }

    dartServices
        .document(request)
        .timeout(serviceCallTimeout)
        .then((DocumentResponse result) {
      final hash = result.hashCode;
      // If nothing has changed, don't need to parse Markdown and
      // manipulate HTML again.
      if (hash == _previousDocHash) {
        return;
      }
      _previousDocHash = hash;

      final docResult = _getHtmlTextFor(result);

      final docType = 'type-${docResult.entityKind}';
      for (final docPanel in docElements) {
        docPanel.setInnerHtml(docResult.html, validator: _htmlValidator);
        for (final a in docPanel.querySelectorAll('a')) {
          if (a is AnchorElement) a.target = 'docs';
        }
        for (final h in docPanel.querySelectorAll('h1')) {
          h.classes.add(docType);
        }
      }
    });
  }

  String _sourceWithCompletionInserted(String source, int offset) {
    var completionText = querySelector('.CodeMirror-hint-active').text;
    var lastSpace = source.substring(0, offset).lastIndexOf(' ') + 1;
    var lastDot = source.substring(0, offset).lastIndexOf('.') + 1;
    var insertOffset = math.max(lastSpace, lastDot);
    return _context.dartSource.substring(0, insertOffset) +
        completionText +
        _context.dartSource.substring(offset);
  }

  _DocResult _getHtmlTextFor(DocumentResponse result) {
    var info = result.info;

    if (info['description'] == null && info['dartdoc'] == null) {
      return _DocResult('');
    }

    var libraryName = info['libraryName'];
    var kind = info['kind'];
    var hasDartdoc = info['dartdoc'] != null;
    var isVariable = kind.contains('variable');

    var apiLink = _dartApiLink(
        libraryName: libraryName,
        enclosingClassName: info['enclosingClassName']);

    var propagatedType = info['propagatedType'];
    var _mdDocs = '''# `${info['description']}`\n\n
${hasDartdoc ? "${info['dartdoc']}\n\n" : ''}
${isVariable ? "$kind\n\n" : ''}
${(isVariable && propagatedType != null) ? "**Propagated type:** $propagatedType\n\n" : ''}
${libraryName == null ? '' : apiLink}\n\n''';

    var _htmlDocs = markdown.markdownToHtml(_mdDocs,
        inlineSyntaxes: [InlineBracketsColon(), InlineBrackets()]);

    // Append a 'launch' icon to the 'Open library docs' link.
    _htmlDocs = _htmlDocs.replaceAll('library docs</a>',
        "library docs <span class='launch-icon'></span></a>");

    return _DocResult(_htmlDocs, kind.replaceAll(' ', '_'));
  }

  String _dartApiLink({String libraryName, String enclosingClassName}) {
    var apiLink = StringBuffer();
    if (libraryName != null) {
      if (libraryName.contains('dart:')) {
        libraryName = libraryName.replaceAll(':', '-');
        apiLink.write(
            'https://api.dart.dev/stable/$libraryName/$libraryName-library.html');

        return '[Open library docs]($apiLink)';
      }
    }
    return libraryName;
  }
}

class _DocResult {
  final String html;
  final String entityKind;

  _DocResult(this.html, [this.entityKind]);
}

class InlineBracketsColon extends markdown.InlineSyntax {
  InlineBracketsColon() : super(r'\[:\s?((?:.|\n)*?)\s?:\]');

  String htmlEscape(String text) => convert.htmlEscape.convert(text);

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    var element = markdown.Element.text('code', htmlEscape(match[1]));
    parser.addNode(element);
    return true;
  }
}

// TODO: [someCodeReference] should be converted to for example
// https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:core.someReference
// for now it gets converted <code>someCodeReference</code>
class InlineBrackets extends markdown.InlineSyntax {
  // This matches URL text in the documentation, with a negative filter
  // to detect if it is followed by a URL to prevent e.g.
  // [text] (http://www.example.com) getting turned into
  // <code>text</code> (http://www.example.com)
  InlineBrackets() : super(r'\[\s?((?:.|\n)*?)\s?\](?!\s?\()');

  String htmlEscape(String text) => convert.htmlEscape.convert(text);

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    var element =
        markdown.Element.text('code', '<em>${htmlEscape(match[1])}</em>');
    parser.addNode(element);
    return true;
  }
}
