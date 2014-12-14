
library editor;

import 'dart:async';
import 'dart:html' as html;

abstract class EditorFactory {
  List<String> get modes;
  List<String> get themes;

  bool get inited;
  Future init();

  Editor createFromElement(html.Element element);
}

abstract class Editor {
  final EditorFactory factory;

  Editor(this.factory);

  Document createDocument({String content, String mode});

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

  bool get isClean;
  void markClean();

  void setAnnotations(List<Annotation> annotations);
  void clearAnnotations() => setAnnotations([]);

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

  final int charStart;
  final int charLength;

  Annotation(this.type, this.message, this.line,
      {this.charStart, this.charLength});

  int compareTo(Annotation other) {
    if (type == other.type){
      return line - other.line;
    } else {
      return _errorValue(other.type) - _errorValue(type);
    }
  }

  String toString() => '${type}, line ${line}: ${message}';
}
