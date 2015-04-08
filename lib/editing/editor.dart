// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library editor;

import 'dart:async';
import 'dart:html' as html;
import 'dart:math';

abstract class EditorFactory {
  List<String> get modes;
  List<String> get themes;

  bool get inited;
  Future init();

  Editor createFromElement(html.Element element);

  bool get supportsCompletionPositioning;

  void registerCompleter(String mode, CodeCompleter completer);
}

abstract class Editor {
  final EditorFactory factory;

  bool completionAutoInvoked = false;

  Editor(this.factory);

  Document createDocument({String content, String mode});

  Document get document;

  /**
   * Runs the command with the given name on the editor. Only implemented for
   * codemirror and comid; returns `null` for ace editor.
   */
  void execCommand(String name);

  /**
   * Checks if the completion popup is displayed. Only implemented for
   * codemirror; returns `null` for ace editor and comid.
   */
  bool get completionActive;

  String get mode;
  set mode(String str);

  String get theme;
  set theme(String str);

  /**
   * Returns the cursor coordinates in pixels. cursorCoords.x corresponds to
   * left and cursorCoords.y corresponds to top. Only implemented for
   * codemirror, returns `null` for ace editor and comid.
   */
  Point get cursorCoords;

  bool get hasFocus;

  /**
   * Fired when a mouse is clicked. You can preventDefault the event to signal
   * that the editor should do no further handling.  Only implemented for
   * codemirror, returns `null` for ace editor and comid.
   */
  Stream<html.MouseEvent> get onMouseDown;

  Stream<CompletionState> get completionState;

  void resize();
  void focus();

  void swapDocument(Document document);

  /// Let the `Editor` instance know that it will no longer be used.
  void dispose() { }
}

abstract class Document {
  final Editor editor;

  Document(this.editor);

  String get value;
  set value(String str);

  Position get cursor;

  void select(Position start, [Position end]);

  /// The currently selected text in the editor.
  String get selection;

  String get mode;

  bool get isClean;
  void markClean();

  void setAnnotations(List<Annotation> annotations);
  void clearAnnotations() => setAnnotations([]);

  int indexFromPos(Position pos);
  Position posFromIndex(int index);

  Stream get onChange;
}

class Annotation implements Comparable {
  static int _errorValue(String type) {
    if (type == 'error') return 2;
    if (type == 'warning') return 1;
    return 0;
  }

  /// info, warning, or error
  final String type;
  final String message;
  final int line;

  final Position start;
  final Position end;

  Annotation(this.type, this.message, this.line,
      {this.start, this.end});

  int compareTo(Annotation other) {
    if (line == other.line) {
      return _errorValue(other.type) - _errorValue(type);
    } else {
      return line - other.line;
    }
  }

  String toString() => '${type}, line ${line}: ${message}';
}

class Position {
  final int line;
  final int char;

  Position(this.line, this.char);

  String toString() => '[${line},${char}]';
}

abstract class CodeCompleter {
  Future<CompletionResult> complete(Editor editor);
}

class CompletionResult {
  final List<Completion> completions;

  /// The start offset of the text to be replaced by a completion.
  final int replaceOffset;

  /// The length of the text to be replaced by a completion.
  final int replaceLength;

  CompletionResult(this.completions, {this.replaceOffset, this.replaceLength});
}

class Completion {
  /// The value to insert.
  final String value;

  /// An optional string that is displayed during auto-completion if specified.
  final String displayString;

  /// The css class type for the completion. This may not be supported by all
  /// completors.
  String type;

  /// The (optional) offset to display the cursor at after completion. This is
  /// relative to the insertion location, not the absolute position in the file.
  /// This may be `null`, and cursor re-positioning may not be supported by all
  /// completors. See [EditorFactory.supportsCompletionPositioning].
  final int cursorOffset;

  Completion(this.value, {this.displayString, this.type, this.cursorOffset});

  bool isSetterAndMatchesGetter(Completion other) =>
      displayString == other.displayString &&
      (type == "type-getter" && other.type == "type-setter");
}

enum CompletionState { SHOWN, CLOSE, UPDATE, PICK, SELECT }