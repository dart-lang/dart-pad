// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.parameter_popup;

import 'dart:convert';
import 'dart:html';
import 'dart:math' as math;

import 'context.dart';
import 'dart_pad.dart';
import 'editing/editor.dart';
import 'services/common.dart';
import 'services/dartservices.dart';

class ParameterPopup {
  static const List parKeys = [
    KeyCode.COMMA,
    KeyCode.NINE,
    KeyCode.ZERO,
    KeyCode.LEFT,
    KeyCode.RIGHT,
    KeyCode.UP,
    KeyCode.DOWN
  ];

  final Context context;
  final Editor editor;

  final HtmlEscape sanitizer = const HtmlEscape();

  ParameterPopup(this.context, this.editor) {
    document.onKeyDown.listen(_handleKeyDown);
    document.onKeyUp.listen(_handleKeyUp);
    document.onClick.listen((e) => _handleClick());
    editor.onMouseDown.listen((e) => _handleClick());
  }

  bool get parPopupActive => querySelector('.parameter-hints') != null;

  void remove() {
    document.body.children.remove(querySelector('.parameter-hints'));
  }

  void _handleKeyDown(KeyboardEvent e) {
    if (e.keyCode == KeyCode.ENTER) {
      // TODO: Use the onClose event of the completion event to trigger this
      _lookupParameterInfo();
    }
  }

  void _handleKeyUp(KeyboardEvent e) {
    if (e.keyCode == KeyCode.ESC ||
        context.focusedEditor != 'dart' ||
        !editor.hasFocus) {
      remove();
    } else if (parPopupActive || parKeys.contains(e.keyCode)) {
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
    var offset = editor.document.indexFromPos(editor.document.cursor);
    var source = editor.document.value;
    var parInfo = _parameterInfo(source, offset);

    if (parInfo == null) {
      remove();
      return;
    }

    var openingParenIndex = parInfo['openingParenIndex'];
    var parameterIndex = parInfo['parameterIndex'];
    offset = openingParenIndex - 1;

    // We request documentation info of what is before the parenthesis.
    var input = SourceRequest()
      ..source = source
      ..offset = offset;

    dartServices
        .document(input)
        .timeout(serviceCallTimeout)
        .then((DocumentResponse result) {
      if (!result.info.containsKey('parameters')) {
        remove();
        return;
      }

      var parameterInfo = result.info['parameters'];
      var outputString = '';
      if (parameterInfo.isEmpty) {
        outputString += '<code>&lt;no parameters&gt;</code>';
      } else if (parameterInfo.length < parameterIndex + 1) {
        outputString += '<code>too many parameters listed</code>';
      } else {
        outputString += '<code>';

        for (var i = 0; i < parameterInfo.length; i++) {
          if (i == parameterIndex) {
            outputString += '<em>${sanitizer.convert(parameterInfo[i])}</em>';
          } else {
            outputString +=
                '<span>${sanitizer.convert(parameterInfo[i])}</span>';
          }
          if (i != parameterInfo.length - 1) {
            outputString += ', ';
          }
        }
        outputString += '</code>';
      }

      // Check if cursor is still in parameter position
      parInfo = _parameterInfo(editor.document.value,
          editor.document.indexFromPos(editor.document.cursor));
      if (parInfo == null) {
        remove();
        return;
      }
      _showParameterPopup(outputString, offset);
    });
  }

  void _showParameterPopup(String string, int methodOffset) {
    var editorDiv = querySelector('#editpanel .CodeMirror') as DivElement;
    var lineHeightStr =
        editorDiv.getComputedStyle().getPropertyValue('line-height');
    var lineHeight =
        int.parse(lineHeightStr.substring(0, lineHeightStr.indexOf('px')));
    // var charWidth = editorDiv.getComputedStyle().getPropertyValue('letter-spacing');
    var charWidth = 8;

    var methodPosition = editor.document.posFromIndex(methodOffset);
    var cursorCoords = editor.getCursorCoords();
    var methodCoords = editor.getCursorCoords(position: methodPosition);
    var heightOfMethod = (methodCoords.y - lineHeight - 5).round();

    DivElement parameterPopup;
    if (parPopupActive) {
      var parameterHint = querySelector('.parameter-hint');
      parameterHint.innerHtml = string;

      //update popup position
      var newLeft = math
          .max(cursorCoords.x - (parameterHint.text.length * charWidth / 2), 22)
          .round();

      parameterPopup = querySelector('.parameter-hints') as DivElement
        ..style.top = '${heightOfMethod}px';
      var oldLeftString = parameterPopup.style.left;
      var oldLeft =
          int.parse(oldLeftString.substring(0, oldLeftString.indexOf('px')));
      if ((newLeft - oldLeft).abs() > 50) {
        parameterPopup.style.left = '${newLeft}px';
      }
    } else {
      var parameterHint = SpanElement()
        ..innerHtml = string
        ..classes.add('parameter-hint');
      var left = math
          .max(cursorCoords.x - (parameterHint.text.length * charWidth / 2), 22)
          .round();
      parameterPopup = DivElement()
        ..classes.add('parameter-hints')
        ..style.left = '${left}px'
        ..style.top = '${heightOfMethod}px'
        ..style.maxWidth =
            "${querySelector("#editpanel").getBoundingClientRect().width}px";
      parameterPopup.append(parameterHint);
      document.body.append(parameterPopup);
    }
    var activeParameter = querySelector('.parameter-hints em');
    if (activeParameter != null &&
        activeParameter.previousElementSibling != null) {
      parameterPopup.scrollLeft =
          activeParameter.previousElementSibling.offsetLeft;
    }
  }

  /// Returns null if the offset is not contained in parenthesis.
  /// Otherwise it will return information about the parameters.
  /// For example, if the source is `substring(1, <caret>)`, it will return
  /// `{openingParenIndex: 9, parameterIndex: 1}`.
  Map<String, int> _parameterInfo(String source, int offset) {
    var parameterIndex = 0;
    var openingParenIndex;
    var nesting = 0;

    while (openingParenIndex == null && offset > 0) {
      offset += -1;
      if (nesting == 0) {
        switch (source[offset]) {
          case '(':
            openingParenIndex = offset;
            break;
          case ',':
            parameterIndex += 1;
            break;
          case ';':
            return null;
          case ')':
            nesting += 1;
            break;
        }
      } else {
        switch (source[offset]) {
          case '(':
            nesting += -1;
            break;
          case ')':
            nesting += 1;
            break;
        }
      }
    }

    return openingParenIndex == null
        ? null
        : {
            'openingParenIndex': openingParenIndex as int,
            'parameterIndex': parameterIndex
          };
  }
}
