// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library editor;

import 'dart:async';
import 'dart:html' as html;

abstract class EditorFactory {
  List<String> get modes;
  List<String> get themes;

  bool get inited;
  Future init();

  Editor createFromElement(html.Element element);

  // TODO: codemirror gives the client more control over where to insert the
  // completions. With Ace, you can only insert from the requested position
  // forward.
  void registerCompleter(String mode, CodeCompleter completer);
}

abstract class Editor {
  final EditorFactory factory;

  Editor(this.factory);

  Document createDocument({String content, String mode});

  Document get document;

  String get mode;
  set mode(String str);

  String get theme;
  set theme(String str);

  void resize();
  void focus();

  void swapDocument(Document document);
}

abstract class Document {
  final Editor editor;

  Document(this.editor);

  String get value;
  set value(String str);

  Position get cursor;

  void select(Position start, [Position end]);

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
  Future<List<Completion>> complete(Editor editor);
}

// TODO: positions?
class Completion {
  /// The value to insert.
  final String value;

  /// An optional string that is displayed during auto-completion if specified.
  final String displayString;

  final String type;

  bool get isMethodWithArguments => displayString.contains("(") && !displayString.contains("()");

  Completion(this.value, {this.displayString, this.type});
}
