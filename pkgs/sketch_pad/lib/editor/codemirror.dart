// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@JS()
library;

import 'dart:js_interop';

import 'package:web/web.dart';

extension type CodeMirrorOptions._(JSObject _) implements JSObject {
  external String theme;
  external String mode;
  external bool autoCloseTags;
  external bool lineNumbers;
  external bool lineWrapping;
  external JSObject extraKeys;
}

extension type CodeMirror._(JSObject _) implements JSObject {
  external static Commands commands;
  external static String get version;
  external static Hint hint;

  external static void registerHelper(
    String type,
    String mode,
    JSFunction helper,
  );

  external factory CodeMirror(Element element, JSAny? codeMirrorOptions);
  external factory CodeMirror.fromTextArea(HTMLTextAreaElement textArea);

  external Events events;

  external HTMLElement getInputField();
  external JSAny getOption(String option);
  external void setOption(String option, JSAny value);
  external Doc getDoc();
  external Position getCursor();
  external JSAny? getHelper(Position pos, String name);

  external void refresh();
  external void focus();
  external void showHint(HintOptions? options);
  external JSAny? execCommand(String command);
  external void on(String event, JSFunction callback);

  String getTheme() => (getOption('theme') as JSString).toDart;
  void setTheme(String theme) => setOption('theme', theme.toJS);

  external void scrollTo(num? x, num? y);
  external ScrollInfo getScrollInfo();

  void setReadOnly(bool value, [bool noCursor = false]) {
    if (value) {
      if (noCursor) {
        setOption('readOnly', 'nocursor'.toJS);
      } else {
        setOption('readOnly', value.toJS);
      }
    } else {
      setOption('readOnly', value.toJS);
    }
  }
}

extension type Commands._(JSObject _) implements JSObject {
  external set goLineLeft(JSFunction callback);
  external set indentIfMultiLineSelectionElseInsertSoftTab(JSFunction callback);
  external set weHandleElsewhere(JSFunction callback);
  external set autocomplete(JSFunction callback);
}

extension type Events._(JSObject _) implements JSObject {
  external set change(JSFunction callback);
}

extension type Doc._(JSObject _) implements JSObject {
  external void setValue(String value);
  external String getValue();
  external String? getLine(int n);
  external bool somethingSelected();
  external String? getSelection(String? s);
  external void setSelection(Position position, [Position head]);
  external JSArray<TextMarker> getAllMarks();
  external TextMarker markText(
      Position from, Position to, MarkTextOptions options);
  external int? indexFromPos(Position pos);
  external void replaceRange(String replacement, Position from,
      [Position? to, String? origin]);
  external Position posFromIndex(int index);
}

@anonymous
extension type ScrollInfo._(JSObject _) implements JSObject {
  external int top;
  external int left;
  external int width;
  external int height;
  external int clientWidth;
  external int clientHeight;
}

@anonymous
extension type Position._(JSObject _) implements JSObject {
  external int line;
  external int ch;

  external factory Position({int line, int ch});
}

extension type TextMarker._(JSObject _) implements JSObject {
  external void clear();
}

@anonymous
extension type MarkTextOptions._(JSObject _) implements JSObject {
  external String className;
  external String title;

  external factory MarkTextOptions({
    String className,
    String title,
  });
}

@anonymous
extension type HintResults._(JSObject _) implements JSObject {
  external JSArray<HintResult> list;
  external Position from;
  external Position to;

  external factory HintResults({
    JSArray<HintResult> list,
    Position from,
    Position to,
  });
}

@anonymous
extension type HintResult._(JSObject _) implements JSObject {
  external String? text;
  external String? displayText;
  external String? className;
  external Position? from;
  external Position? to;
  external JSFunction? hintRenderer;
  external JSFunction? hint;

  external factory HintResult({
    String? text,
    String? displayText,
    String? className,
    Position? from,
    Position? to,
    JSFunction? hintRenderer,
    JSFunction? hint,
  });
}

@anonymous
extension type HintOptions._(JSObject _) implements JSObject {
  external JSAny hint;
  external HintResults results;

  external factory HintOptions({JSAny hint, HintResults results});
}

extension type Hint._(JSObject _) implements JSObject {
  external JSAny dart;
}
