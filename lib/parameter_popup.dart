// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.parameter_popup;

import 'dart:convert';
import 'dart:html';
import 'dart:math' as math;

import 'context.dart';
import 'dartservices_client/v1.dart';
import 'editing/editor.dart';
import 'services/common.dart';

class ParameterPopup {
  static const List parKeys = const[
      KeyCode.COMMA, KeyCode.NINE, KeyCode.ZERO,
      KeyCode.LEFT, KeyCode.RIGHT, KeyCode.UP, KeyCode.DOWN
  ];

  final DartservicesApi servicesApi;
  final Context context;
  final Editor editor;

  final HtmlEscape sanitizer = const HtmlEscape();

  ParameterPopup(this.servicesApi, this.context, this.editor) {
    document.onKeyDown.listen((e) => _handleKeyDown(e));
    document.onKeyUp.listen((e) => _handleKeyUp(e));
    document.onClick.listen((e) => _handleClick());
    editor.onMouseDown.listen((e) => _handleClick());
  }

  bool get parPopupActive => querySelector(".parameter-hints") != null;

  void remove() {
    document.body.children.remove(querySelector(".parameter-hints"));
  }

  void _handleKeyDown(KeyboardEvent e) {
    if (e.keyCode == KeyCode.ENTER) {
      _lookupParameterInfo();
    }
  }

  void _handleKeyUp(KeyboardEvent e) {
    if (parPopupActive && e.keyCode == KeyCode.ESC) {
      remove();
      return;
    }
    if (parPopupActive || parKeys.contains(e.keyCode)) {
      _lookupParameterInfo();
    }
  }

  void _handleClick() {
    if (context.focusedEditor != 'dart' || !editor.hasFocus) {
      remove();
    } else {
      _lookupParameterInfo();
    }
  }

  void _lookupParameterInfo() {
    int offset = editor.document.indexFromPos(editor.document.cursor);
    String source = editor.document.value;
    Map<String, int> parInfo = _parameterInfo(source, offset);

    if (parInfo == null) {
      remove();
      return;
    }

    int openingParenIndex = parInfo["openingParenIndex"];
    int parameterIndex = parInfo["parameterIndex"];
    offset = openingParenIndex - 1;

    // We request documentation info of what is before the parenthesis.
    SourceRequest input = new SourceRequest()
      ..source = source
      ..offset = offset;

    servicesApi.document(input).timeout(serviceCallTimeout).then(
        (DocumentResponse result) {
      if (!result.info.containsKey("parameters")) {
        remove();
        return;
      }
      List parameterInfo = result.info["parameters"] as List;
      String outputString = "";
      if (parameterInfo.length == 0) {
        outputString += "<code>&lt;no parameters&gt;</code>";
      } else if (parameterInfo.length < parameterIndex + 1) {
        outputString += "<code>too many parameters listed</code>";
      } else {
        outputString += "<code>";

        for (int i = 0; i < parameterInfo.length; i++) {
          if (i == parameterIndex) {
            outputString += '<em>${parameterInfo[i]}</em>';
          } else {
            outputString += '${sanitizer.convert(parameterInfo[i])}';
          }
          if (i != parameterInfo.length - 1) {
            outputString += ", ";
          }
        }
        outputString += "</code>";
      }

      // Check if cursor is still in parameter position
      offset = editor.document.indexFromPos(editor.document.cursor);
      source = editor.document.value;
      parInfo = _parameterInfo(source, offset);
      if (parInfo == null) {
        remove();
        return;
      }
      _showParameterPopup(outputString);
    });
  }

  void _showParameterPopup(String string) {
    DivElement editorDiv = querySelector("#editpanel .CodeMirror");
    var lineHeight = editorDiv.getComputedStyle().getPropertyValue('line-height');
    lineHeight = int.parse(lineHeight.substring(0, lineHeight.indexOf("px")));
    // var charWidth = editorDiv.getComputedStyle().getPropertyValue('letter-spacing');
    int charWidth = 8;

    Point cursorCoords = editor.cursorCoords;

    if (parPopupActive) {
      var parameterHint = querySelector(".parameter-hint");
      parameterHint.innerHtml = string;

      //update popup position
      int newLeft = math.max(
          cursorCoords.x - (parameterHint.text.length * charWidth ~/ 2), 0);

      var parameterPopup = querySelector(".parameter-hints")
        ..style.top = "${cursorCoords.y - lineHeight - 5}px";
      var oldLeft = parameterPopup.style.left;
      oldLeft = int.parse(oldLeft.substring(0, oldLeft.indexOf("px")));
      if ((newLeft - oldLeft).abs() > 50) {
        parameterPopup.style.left = "${newLeft}px";
      }
    } else {
      var parameterHint = new SpanElement()
        ..innerHtml = string
        ..classes.add("parameter-hint");
      int left = math.max(
          cursorCoords.x - (parameterHint.text.length * charWidth ~/ 2), 0);
      var parameterPopup = new DivElement()
        ..classes.add("parameter-hints")
        ..style.left = "${left}px"
        ..style.top = "${cursorCoords.y - lineHeight - 5}px";
      parameterPopup.append(parameterHint);
      document.body.append(parameterPopup);
    }
  }

  /// Returns null if the offset is not contained in parenthesis.
  /// Otherwise it will return information about the parameters.
  /// For example, if the source is `substring(1, <caret>)`, it will return
  /// `{openingParenIndex: 9, parameterIndex: 1}`.
  Map<String, int> _parameterInfo(String source, int offset) {
    int parameterIndex = 0;
    int openingParenIndex;
    int nesting = 0;

    while (openingParenIndex == null && offset > 0) {
      offset += -1;
      if (nesting == 0) {
        switch (source[offset]) {
          case "(":
            openingParenIndex = offset;
            break;
          case ",":
            parameterIndex += 1;
            break;
          case ";":
            return null;
          case ")":
            nesting += 1;
            break;
        }
      } else {
        switch (source[offset]) {
          case "(":
            nesting += -1;
            break;
          case ")":
            nesting += 1;
            break;
        }
      }
    }

    return openingParenIndex == null ? null : {
      "openingParenIndex" : openingParenIndex,
      "parameterIndex" : parameterIndex
    };
  }
}
