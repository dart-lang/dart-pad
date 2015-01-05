// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library playground;

import 'dart:async';
import 'dart:html' hide Document;

import 'context.dart';
import 'dartpad.dart';
import 'core/dependencies.dart';
import 'core/modules.dart';
import 'editing/editor.dart';
import 'elements/elements.dart';
import 'modules/ace_module.dart';
//import 'modules/codemirror_module.dart';
import 'modules/dartpad_module.dart';
//import 'modules/mock_analysis.dart';
//import 'modules/mock_compiler.dart';
import 'modules/server_analysis.dart';
import 'modules/server_compiler.dart';
import 'services/analysis.dart';
import 'services/common.dart';
import 'services/compiler.dart';

// TODO: console output needs to scroll the output field

// TODO: we need blinkers when something happens. console is appended to,
// css is updated, result area dom is modified.

// TODO: we need a component for the output area

Playground get playground => _playground;

Playground _playground;

void init() {
  _playground = new Playground();
}

class Playground {
  DivElement get _editpanel => querySelector('#editpanel');
  DivElement get _outputpanel => querySelector('#output');
  IFrameElement get _frame => querySelector('#frame');
  //Element get _spinner => querySelector('#spinner');

  DButton runbutton;
  Editor editor;
  PlaygroundContext _context;

  ModuleManager modules = new ModuleManager();
  ExecutionService executionService;

  Playground() {
    _registerTab(querySelector('#darttab'), 'dart');
    _registerTab(querySelector('#htmltab'), 'html');
    _registerTab(querySelector('#csstab'), 'css');

    // Set up iframe.
    executionService = new ExecutionService(_frame);
    executionService.onStdout.listen(_showOuput);
    executionService.onStderr.listen(_showErrorOuput);

    runbutton = new DButton(querySelector('#runbutton'));
    runbutton.onClick.listen((e) {
      _handleRun();
      _context.focus();
    });

    _initModules().then((_) {
      _initPlayground();
    });
  }

  Future _initModules() {
    modules.register(new DartpadModule());
    //modules.register(new MockAnalysisModule());
    modules.register(new ServerAnalysisModule());
    //modules.register(new MockCompilerModule());
    modules.register(new ServerCompilerModule());
    modules.register(new AceModule());
    //modules.register(new CodeMirrorModule());

    return modules.start();
  }

  void _initPlayground() {
    // Set up the editing area.
    editor = editorFactory.createFromElement(_editpanel);
    _editpanel.children.first.attributes['flex'] = '';
    editor.resize();

    keys.bind('ctrl-s', _handleSave);
    keys.bind('ctrl-enter', _handleRun);

    _context = new PlaygroundContext(editor);
    deps[Context] = _context;

    _context.onHtmlReconcile.listen((_) {
      executionService.replaceHtml(_context.htmlSource);
      _context.markHtmlClean();
    });

    _context.onCssReconcile.listen((_) {
      executionService.replaceCss(_context.cssSource);
      _context.markCssClean();
    });

    _context.onDartReconcile.listen((_) {
      String source = _context.dartSource;
      Lines lines = new Lines(source);

      analysisService.analyze(source).then((AnalysisResults result) {
        _context.dartDocument.setAnnotations(result.issues.map(
            (AnalysisIssue issue) {
          int startLine = lines.getLineForOffset(issue.charStart);
          int endLine = lines.getLineForOffset(issue.charStart + issue.charLength);

          Position start = new Position(startLine,
              issue.charStart - lines.offsetForLine(startLine));
          Position end = new Position(endLine,
              issue.charStart + issue.charLength - lines.offsetForLine(startLine));

          return new Annotation(issue.kind, issue.message, issue.line,
              start: start, end: end);
        }).toList());
      });
    });
  }

  void _registerTab(Element element, String name) {
    DElement component = new DElement(element);

    component.onClick.listen((_) {
      if (component.hasAttr('selected')) return;

      component.setAttr('selected');

      _getTabElements(component.element.parent.parent).forEach((c) {
        if (c != component.element && c.attributes.containsKey('selected')) {
          c.attributes.remove('selected');
        }
      });

      _context.switchTo(name);
    });
  }

  List<Element> _getTabElements(Element element) => element.querySelectorAll('a');

  void _handleRun() {
    runbutton.disabled = true;
    _showSpinner(true);

    compilerService.compile(context.dartSource).then((CompilerResult result) {
      _clearOutput();
      return executionService.execute(
          _context.htmlSource, _context.cssSource, result.output);
    }).catchError((e) {
      // TODO: Also display using a toast.
      _clearOutput();
      _showErrorOuput('Error compiling:\n${e}');
    }).whenComplete(() {
      _context.markCssClean();
      runbutton.disabled = false;
      _showSpinner(false);
    });
  }

  void _showSpinner(bool show) {
    //_spinner.classes.toggle('showing', show);
  }

  void _handleSave() {
    // TODO:
    print('handleSave');
    _context.focus();
  }

  void _showOuput(String message) {
    _outputpanel.text += message;
  }

  void _showErrorOuput(String message) {
    SpanElement span = new SpanElement();
    span.classes.add('errorOutput');
    span.text = message;
    _outputpanel.children.add(span);
  }

  void _clearOutput() {
    _outputpanel.text = '';
  }
}

class PlaygroundContext extends Context {
  final Editor editor;

  Document _dartDoc;
  Document _htmlDoc;
  Document _cssDoc;

  StreamController _htmlReconcileController = new StreamController.broadcast();
  StreamController _cssReconcileController = new StreamController.broadcast();
  StreamController _dartReconcileController = new StreamController.broadcast();

  PlaygroundContext(this.editor) {
    _dartDoc = editor.createDocument(
        content: _sampleDartCode, mode: 'dart');
    _htmlDoc = editor.createDocument(
        content: _sampleHtmlCode, mode: 'html');
    _cssDoc = editor.createDocument(
        content: _sampleCssCode, mode: 'css');

    _createReconciler(_htmlDoc, _htmlReconcileController, 250);
    _createReconciler(_cssDoc, _cssReconcileController, 250);
    _createReconciler(_dartDoc, _dartReconcileController);

    editor.swapDocument(_dartDoc);
  }

  Document get dartDocument => _dartDoc;

  String get dartSource => _dartDoc.value;
  set dartSource(String value) {
    _dartDoc.value = dartSource;
  }

  String get htmlSource => _htmlDoc.value;
  set htmlSource(String value) {
    _htmlDoc.value = value;
  }

  String get cssSource => _cssDoc.value;
  set cssSource(String value) {
    _cssDoc.value = value;
  }

  void switchTo(String name) {
    if (name == 'dart') {
      editor.swapDocument(_dartDoc);
    } else if (name == 'html') {
      editor.swapDocument(_htmlDoc);
    } else if (name == 'css') {
      editor.swapDocument(_cssDoc);
    }

    editor.focus();
  }

  Stream get onHtmlReconcile => _htmlReconcileController.stream;

  Stream get onCssReconcile => _cssReconcileController.stream;

  Stream get onDartReconcile => _dartReconcileController.stream;

  void markHtmlClean() => _htmlDoc.markClean();

  void markCssClean() => _cssDoc.markClean();

  /**
   * Restore the focus to the last focused editor.
   */
  void focus() => editor.focus();

  void _createReconciler(Document doc, StreamController controller,
      [int delay = 1250]) {
    Timer timer;
    doc.onChange.listen((_) {
      if (timer != null) timer.cancel();
      timer = new Timer(new Duration(milliseconds: delay), () {
        if (!doc.isClean) {
          controller.add(null);
        }
      });
    });
  }
}

final String _sampleDartCode = r'''void main() {
  for (int i = 0; i < 4; i++) {
    print('hello ${i}');
  }
}
''';

// TODO: better sample code

final String _sampleHtmlCode = r'''<h2>Dart Sample</h2>

<p id="output">Hello world!<p>
''';

final String _sampleCssCode = r'''/* my styles */

h2 {
  font-weight: normal;
  margin-top: 0;
}

p {
  color: #888;
}
''';

// TODO: move into it's own file

class ExecutionService {
  final StreamController _stdoutController = new StreamController.broadcast();
  final StreamController _stderrController = new StreamController.broadcast();

  final IFrameElement frame;

  ExecutionService(this.frame) {
    window.onMessage.listen((MessageEvent event) {
      String message = '${event.data}\n';

      if (message.startsWith('stderr: ')) {
        _stderrController.add(message.substring(8));
      } else {
        _stdoutController.add(message);
      }
    });
  }

  Future execute(String html, String css, String javaScript) {
    final String postMessagePrint =
        "function dartPrint(message) { parent.postMessage(message, '*'); }";

    // TODO: Use a better encoding than 'stderr: '.
    final String exceptionHandler =
        "window.onerror = function(message, url, lineNumber) { "
        "parent.postMessage('stderr: ' + message.toString(), '*'); };";

    replaceCss(css);
    replaceHtml(html);
    replaceJavaScript('${postMessagePrint}\n${exceptionHandler}\n${javaScript}');

    return new Future.value();
  }

  void replaceCss(String css) {
    _send('setCss', css);
  }

  void replaceHtml(String html) {
    _send('setHtml', html);
  }

  void replaceJavaScript(String js) {
    _send('setJavaScript', js);
  }

  void reset() {
    _send('reset');
  }

  Stream<String> get onStdout => _stdoutController.stream;

  Stream<String> get onStderr => _stderrController.stream;

  void _send(String command, [String data]) {
    Map m = {'command': command};
    if (data != null) m['data'] = data;
    frame.contentWindow.postMessage(m, '*');
  }
}
