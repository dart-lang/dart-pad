// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.documentation;

import 'dart:async';
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
  static const List cursorKeys = [
    KeyCode.LEFT,
    KeyCode.RIGHT,
    KeyCode.UP,
    KeyCode.DOWN
  ];

  final Editor _editor;
  final Context _context;

  final NodeValidator _htmlValidator = PermissiveNodeValidator();

  DocHandler(this._editor, this._context);

  void generateDocWithText(DivElement docPanel) {
    if (_context.focusedEditor != 'dart') {
      docPanel.innerHtml = 'Documentation';
      return;
    }
    if (!_editor.hasFocus || _editor.document.selection.isNotEmpty) {
      return;
    }

    var offset = _editor.document.indexFromPos(_editor.document.cursor);

    var request = SourceRequest()..offset = offset;

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
      return _getHtmlTextFor(result).then((_DocResult docResult) {
        if (docResult.html == '') {
          docPanel.innerHtml =
              "<div class='default-text-div layout horizontal center-center'>"
              "<span class='default-text'>Documentation</span></div>";
          return;
        }
        docPanel.setInnerHtml(docResult.html, validator: _htmlValidator);
        for (final a in docPanel.querySelectorAll('a')) {
          if (a is AnchorElement) a.target = 'docs';
        }
        for (final h in docPanel.querySelectorAll('h1')) {
          h.classes.add('type-${docResult.entitykind}');
        }
      });
    });
  }

  void generateDoc(DivElement docPanel) {
    if (_context.focusedEditor != 'dart') {
      docPanel.innerHtml = '';
      return;
    }
    if (!_editor.hasFocus || _editor.document.selection.isNotEmpty) {
      return;
    }

    var offset = _editor.document.indexFromPos(_editor.document.cursor);

    var request = SourceRequest()..offset = offset;

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
      return _getHtmlTextFor(result).then((_DocResult docResult) {
        docPanel.setInnerHtml(docResult.html, validator: _htmlValidator);
        for (final a in docPanel.querySelectorAll('a')) {
          if (a is AnchorElement) a.target = 'docs';
        }
        for (final h in docPanel.querySelectorAll('h1')) {
          h.classes.add('type-${docResult.entitykind}');
        }
      });
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

  Future<_DocResult> _getHtmlTextFor(DocumentResponse result) {
    var info = result.info;

    if (info['description'] == null && info['dartdoc'] == null) {
      return Future.value(_DocResult(''));
    }

    var libraryName = info['libraryName'];
    var domName = info['DomName'];
    var kind = info['kind'];
    var hasDartdoc = info['dartdoc'] != null;
    var isHtmlLib = libraryName == 'dart:html';
    var isVariable = kind.contains('variable');

    var apiLink = _dartApiLink(
        libraryName: libraryName,
        enclosingClassName: info['enclosingClassName']);

    var mdnCheck = Future<String>.value();
    if (!hasDartdoc && isHtmlLib && domName != null) {
      mdnCheck = createMdnMarkdownLink(domName);
    }

    return mdnCheck.then((String mdnLink) {
      var propagatedType = info['propagatedType'];
      var _mdDocs = '''# `${info['description']}`\n\n
${hasDartdoc ? "${info['dartdoc']}\n\n" : ''}
${mdnLink != null ? "## External resources:\n * $mdnLink at MDN" : ''}
${isVariable ? "$kind\n\n" : ''}
${(isVariable && propagatedType != null) ? "**Propagated type:** $propagatedType\n\n" : ''}
${libraryName == null ? '' : apiLink}\n\n''';

      var _htmlDocs = markdown.markdownToHtml(_mdDocs,
          inlineSyntaxes: [InlineBracketsColon(), InlineBrackets()]);

      // Append a 'launch' icon to the 'Open library docs' link.
      _htmlDocs = _htmlDocs.replaceAll('library docs</a>',
          "library docs <span class='launch-icon'></span></a>");

      return _DocResult(_htmlDocs, kind.replaceAll(' ', '_'));
    });
  }

  String _dartApiLink({String libraryName, String enclosingClassName}) {
    var apiLink = StringBuffer();
    if (libraryName != null) {
      if (libraryName.contains('dart:')) {
        libraryName = libraryName.replaceAll(':', '-');
        apiLink.write(
            'https://api.dartlang.org/stable/$libraryName/$libraryName-library.html');

        return '[Open library docs]($apiLink)';
      }
    }
    return libraryName;
  }
}

/// Returns the markdown url link for the MDN documentation for the given DOM
/// element name, or `null` if no documentation URL for that element exits.
Future<String> createMdnMarkdownLink(String domName) {
  final baseUrl = 'https://developer.mozilla.org/en-US/docs/Web/API/';

  var domClassName =
      domName.contains('.') ? domName.substring(0, domName.indexOf('.')) : null;

  return _urlExists('$baseUrl$domName').then((bool exists) {
    if (exists) return '[$domName]($baseUrl$domName)';

    if (domClassName != null) {
      return _urlExists('$baseUrl$domClassName').then((bool exists) {
        return exists ? '[$domClassName]($baseUrl$domClassName)' : null;
      });
    }

    return null;
  });

  // Avoid searching for now.
  //String searchUrl = "https://developer.mozilla.org/en-US/search?q=";
  //return 'Search for [$domName]($searchUrl$domName)';
}

Future<bool> _urlExists(String url) {
  return HttpRequest.getString(url).then((_) => true).catchError((e) => false);
}

class _DocResult {
  final String html;
  final String entitykind;

  _DocResult(this.html, [this.entitykind]);
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
