// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO Rename the file to `documentation.dart`?

library dartpad.doc_handler;

import 'dart:convert';
import 'dart:html';
import 'dart:math' as math;
import 'dart:async';

import 'package:markd/markdown.dart' as markdown;

import 'context.dart';
import 'editing/editor.dart';
import 'dart_pad.dart';
import 'dartservices_client/v1.dart';
import 'services/common.dart';

class DocHandler {
  static const List cursorKeys = const [
    KeyCode.LEFT,
    KeyCode.RIGHT,
    KeyCode.UP,
    KeyCode.DOWN
  ];

  final Editor _editor;
  final Context _context;

  final NodeValidatorBuilder _htmlValidator = new NodeValidatorBuilder.common()
    ..allowElement('a', attributes: ['href'])
    ..allowElement('img', attributes: ['src']);

  DocHandler(this._editor, this._context);

  void generateDoc(DivElement docPanel) {
    if (!(_context.focusedEditor == 'dart'
        && _editor.hasFocus
        && _editor.document.selection.isEmpty)) {
      return;
    }

    SourceRequest input;
    int offset = _editor.document.indexFromPos(_editor.document.cursor);

    if (_editor.completionActive) {
      // If the completion popup is open we create a new source as if the
      // completion popup was chosen, and ask for the documentation of that
      // source.
      String source = _sourceWithCompletionInserted(_context.dartSource,offset);
      input = new SourceRequest()
        ..source = source
        ..offset = offset;
    } else {
      input = new SourceRequest()
        ..source = _context.dartSource
        ..offset = offset;
    }

    // TODO: Show busy.
    dartServices.document(input).timeout(serviceCallTimeout).then(
        (DocumentResponse result) async {
      Map info = result.info;
      String kind = info['kind'];
      if (info['description'] == null && info['dartdoc'] == null) {
        docPanel.setInnerHtml("<p>No documentation found.</p>");
      } else {
        String apiLink = _dartApiLink(
            libraryName: info['libraryName'],
            enclosingClassName: info['enclosingClassName'],
            memberName: info["name"]
        );
        String mdnLink;
        if (info["libraryName"] == "dart:html" && info["DomName"] != null) {
          mdnLink = await _mdnApiLink(info['DomName']);
        }
        docPanel.setInnerHtml(markdown.markdownToHtml(
'''
# `${info['description']}`\n\n
${info['dartdoc'] != null ? info['dartdoc'] + "\n\n" : ""}
${mdnLink == null || info['dartdoc'] != null ? "" : "## External resources:\n * $mdnLink at MDN"}
${kind.contains("variable") ? "${info['kind']}\n\n" : ""}
${kind.contains("variable") ? "**Propagated type:** ${info["propagatedType"]}\n\n" : ""}
${info['libraryName'] == null ? "" : "**Library:** $apiLink" }\n\n
''', inlineSyntaxes: [new InlineBracketsColon(), new InlineBrackets()]),
          validator: _htmlValidator);

        docPanel.querySelectorAll("a").forEach((AnchorElement a)
        => a.target = "_blank");
        docPanel.querySelectorAll("h1").forEach((h)
        => h.classes.add("type-${kind.replaceAll(" ","_")}"));
      }
    });
  }

  String _sourceWithCompletionInserted(String source, int offset) {
    String completionText = querySelector(".CodeMirror-hint-active").text;
    int lastSpace = source.substring(0, offset).lastIndexOf(" ") + 1;
    int lastDot = source.substring(0, offset).lastIndexOf(".") + 1;
    int insertOffset = math.max(lastSpace, lastDot);
    return _context.dartSource.substring(0, insertOffset) +
    completionText +
    _context.dartSource.substring(offset);
  }

  String _dartApiLink({String libraryName, String enclosingClassName, String memberName}){
    StringBuffer apiLink = new StringBuffer();
    if (libraryName != null) {
      if (libraryName.contains("dart:")) {
        apiLink.write("https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/$libraryName");
        memberName = '${memberName == null ? "" : "#id_$memberName"}';
        if (enclosingClassName == null) {
          apiLink.write(memberName);
        } else {
          apiLink.write(".$enclosingClassName$memberName");
        }
        return '[$libraryName]($apiLink)';
      }
    }
    return libraryName;
  }

  Future<String> _mdnApiLink(String domName) async{

    String domClassName;
    if (domName.indexOf(".") != -1) {
      domClassName = domName.substring(0, domName.indexOf("."));
    }
    String baseUrl = "https://developer.mozilla.org/en-US/docs/Web/API/";

    if (await urlExists('$baseUrl$domName')) {
      return '[$domName]($baseUrl$domName)';
    } else if (domClassName != null && await urlExists('$baseUrl$domClassName')) {
      return '[$domClassName]($baseUrl$domClassName)';
    } else {
      String searchUrl = "https://developer.mozilla.org/en-US/search?q=";
      return 'Search for [$domName]($searchUrl$domName)';
    }
  }

  Future<bool> urlExists(String url) async {
    try {
      await HttpRequest.getString(url);
      return true;
    } catch(error) {
      return false;
    }
  }
}

class InlineBracketsColon extends markdown.InlineSyntax {
  InlineBracketsColon() : super(r'\[:\s?((?:.|\n)*?)\s?:\]');

  String htmlEscape(String text) => HTML_ESCAPE.convert(text);

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    var element = new markdown.Element.text('code', htmlEscape(match[1]));
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

  String htmlEscape(String text) => HTML_ESCAPE.convert(text);

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    var element = new markdown.Element.text(
        'code', "<em>${htmlEscape(match[1])}</em>");
    parser.addNode(element);
    return true;
  }
}
