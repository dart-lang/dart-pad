
library editor.codemirror;

import 'dart:async';
import 'dart:html' as html;

import 'package:codemirror/codemirror.dart';

import 'editor.dart';

export 'editor.dart';

// extraKeys: {"Ctrl-Space": "autocomplete"}
//<script src="../addon/hint/show-hint.js"></script>
//<script src="../addon/hint/xml-hint.js"></script>
//<script src="../addon/hint/html-hint.js"></script>

final CodeMirrorFactory codeMirrorFactory = new CodeMirrorFactory._();

class CodeMirrorFactory extends EditorFactory {
  static final String cssRef = 'packages/dartpad_ui/editing/editor_codemirror.css';
  static final String jsRef = 'packages/codemirror/codemirror.js';

  CodeMirrorFactory._();

  List<String> get modes => CodeMirror.MODES;
  List<String> get themes => CodeMirror.THEMES;

  bool get inited {
    List scripts = html.querySelectorAll('head script');
    return scripts.any((script) => script.src == jsRef);
  }

  Future init() {
    List futures = [];
    html.Element head = html.querySelector('html head');

    // <link href="packages/dartpad_ui/editing/editor_codemirror.css"
    //   rel="stylesheet">
    html.LinkElement link = new html.LinkElement();
    link.rel = 'stylesheet';
    link.href = cssRef;
    futures.add(_appendNode(head, link));

    // <script src="packages/codemirror/codemirror.js"></script>
    html.ScriptElement script = new html.ScriptElement();
    script.src = jsRef;
    futures.add(_appendNode(head, script));

    return Future.wait(futures);
  }

  Editor createFromElement(html.Element element, {Map options}) {
    if (options == null) {
      options = {
        'matchBrackets': true,
        'tabSize': 2,
        'indentUnit': 2,
        'autofocus': true,
        'cursorHeight': 0.85,
        'autoCloseBrackets': true,
        //'gutters': ['issuesgutter'],
        'theme': 'ambiance' // ambiance, vibrant-ink, monokai
      };
    }

    return new _CodeMirrorEditor._(this,
        new CodeMirror.fromElement(element, options: options));
  }
}

class _CodeMirrorEditor extends Editor {
  final CodeMirror cm;

  _CodeMirrorDocument _document;

  _CodeMirrorEditor._(CodeMirrorFactory factory, this.cm) : super(factory) {
    _document = new _CodeMirrorDocument._(this, cm.getDoc());
  }

  Document createDocument({String content, String mode}) {
    // TODO: use dart when available
    if (mode == 'dart') mode = 'javascript';
    if (mode == 'html') mode = 'text/html';

    if (content == null) content = '';
    Doc doc = new Doc(content, mode);
    return new _CodeMirrorDocument._(this, doc);
  }

  String get mode => cm.getMode();
  set mode(String str) => cm.setMode(str);

  String get theme => cm.getTheme();
  set theme(String str) => cm.setTheme(str);

  void focus() => cm.focus();
  void resize() => cm.refresh();

  void swapDocument(Document document) {
    _document = document;
    cm.swapDoc(_document.doc);
  }
}

class _CodeMirrorDocument extends Document {
  final Doc doc;

  _CodeMirrorDocument._(_CodeMirrorEditor editor, this.doc) : super(editor);

  _CodeMirrorEditor get parent => editor;

  String get value => doc.getValue();
  set value(String str) => doc.setValue(str);

  bool get isClean => doc.isClean();
  void markClean() => doc.markClean();

  void setAnnotations(List<Annotation> annotations) {
    // TODO: implement

  }

  Stream get onChange => doc.onChange;
}

Future _appendNode(html.Element parent, html.Element child) {
  Completer completer = new Completer();
  child.onLoad.listen((e) {
    completer.complete();
  });
  parent.nodes.add(child);
  return completer.future;
}
