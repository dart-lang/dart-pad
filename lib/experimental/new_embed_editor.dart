import 'dart:html' hide Document;

import '../editing/editor.dart' hide Position;
import '../editing/editor.dart' as ed show Position;

class NewEmbedEditor extends Editor {
  NewEmbedEditor(NewEmbedEditorFactory factory, this.textarea) : super(factory) {
    _document = NewEmbedDocument(this, '');
  }

  final TextAreaElement textarea;

  NewEmbedDocument _document;

  @override
  String mode;

  @override
  String theme;

  @override
  bool get completionActive => false;

  @override
  Document createDocument({String content, String mode}) {
    return NewEmbedDocument(this, content);
  }

  @override
  Document get document => _document;

  @override
  void execCommand(String name) {
    // TODO: implement execCommand
  }

  @override
  void focus() {
    // TODO: implement focus
  }

  @override
  Point<num> getCursorCoords({ed.Position position}) {
    return Point<num>(0, 0);
  }

  @override
  bool get hasFocus => true;

  @override
  Stream<MouseEvent> get onMouseDown => textarea.onMouseDown;

  @override
  void resize() {
    // TODO: implement resize
  }

  @override
  void showCompletions({bool autoInvoked = false, bool onlyShowFixes = false}) {
  }

  @override
  void swapDocument(Document document) {
    if (document is NewEmbedDocument) {
      _document = _document;
    }
  }
}

class NewEmbedEditorFactory extends EditorFactory {
  @override
  Editor createFromElement(Element element) {
    return NewEmbedEditor(this, element);
  }

  @override
  List<String> get modes => ['dart'];

  @override
  void registerCompleter(String mode, CodeCompleter completer) {
    // TODO: implement registerCompleter
  }

  @override
  List<String> get themes => ['normal'];
}

class NewEmbedDocument extends Document {
  NewEmbedDocument(NewEmbedEditor editor, this.doc) : super(editor);

  NewEmbedEditor get parent => editor;

  String doc;

  String get value => doc;

  set value(String str) {
    doc = str;
  }

  void updateValue(String str) {
    doc = str;
  }

  ed.Position get cursor => ed.Position(0, 0);

  void select(ed.Position start, [ed.Position end]) {}

  String get selection => '';

  String get mode => parent.mode;

  bool get isClean => false;

  void markClean() => () {};

  void applyEdit(SourceEdit edit) {}

  void setAnnotations(List<Annotation> annotations) {}

  int indexFromPos(ed.Position position) => 0;

  ed.Position posFromIndex(int index) => null;

  Stream get onChange {
    return null;
  }
}
