// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library playground;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' hide Document;

import 'package:logging/logging.dart';
import 'package:route_hierarchical/client.dart';

import 'codepad.dart';
import 'context.dart';
import 'core/dependencies.dart';
import 'core/modules.dart';
import 'editing/editor.dart';
import 'elements/elements.dart';
//import 'modules/ace_module.dart';
import 'modules/codemirror_module.dart';
import 'modules/codepad_module.dart';
import 'modules/server_analysis.dart';
import 'modules/server_compiler.dart';
import 'services/analysis.dart';
import 'services/common.dart';
import 'services/compiler.dart';
import 'services/execution_iframe.dart';
import 'src/ga.dart';
import 'src/sample.dart' as sample;
import 'src/util.dart';

// TODO: we need blinkers when something happens. console is appended to,
// css is updated, result area dom is modified.

Playground get playground => _playground;

Playground _playground;
Analytics ga = new Analytics();

Logger _logger = new Logger('codepad');

void init() {
  _playground = new Playground();
}

class Playground {
  DivElement get _editpanel => querySelector('#editpanel');
  DivElement get _outputpanel => querySelector('#output');
  IFrameElement get _frame => querySelector('#frame');

  DButton runbutton;
  DBusyLight dartBusyLight;
  DBusyLight cssBusyLight;
  DBusyLight htmlBusyLight;
  Editor editor;
  PlaygroundContext _context;
  Future _analysisRequest;
  Router _router;

  ModuleManager modules = new ModuleManager();

  Playground() {
    _registerTab(querySelector('#darttab'), 'dart');
    _registerTab(querySelector('#htmltab'), 'html');
    _registerTab(querySelector('#csstab'), 'css');

    runbutton = new DButton(querySelector('#runbutton'));
    runbutton.onClick.listen((e) {
      _handleRun();

      // On a mobile device, focusing the editing are causes the keyboard to pop
      // up when the user hits the run button.
      if (!isMobile()) _context.focus();
    });

    // TODO: Currently the lights are all shared; we should have one for each
    // type.
    dartBusyLight = new DBusyLight(querySelector('#dartbusy'));
    cssBusyLight = new DBusyLight(querySelector('#dartbusy'));
    htmlBusyLight = new DBusyLight(querySelector('#dartbusy'));

    SelectElement select = querySelector('#samples');
    select.onChange.listen((_) => _handleSelectChanged(select));

    _initModules().then((_) {
      _initPlayground();
    });
  }

  void showHome(RouteEnterEvent event) {
    _logger.info('routed to showHome, ${window.location}, ${event.parameters}');

    // TODO(devoncarew): Hack, until we resolve the issue with routing.
    String path = window.location.pathname;
    if (path.length > 2 && path.lastIndexOf('/') == 0) {
      String id = path.substring(1);
      if (_isLegalGistId(id)) {
        _showGist(id);
        return;
      }
    }

    _setGistDescription(null);
    _setGistId(null, null);

    context.dartSource = sample.dartCode;
    context.htmlSource = sample.htmlCode;
    context.cssSource = sample.cssCode;

    Timer.run(_handleRun);
  }

  void showGist(RouteEnterEvent event) {
    _logger.info('routed to showGist, ${window.location}, ${event.parameters}');

    String gistId = event.parameters['gist'];

    if (!_isLegalGistId(gistId)) {
      showHome(event);
      return;
    }

    _showGist(gistId);
  }

  void _showGist(String gistId) {
    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    HttpRequest.getString('https://api.github.com/gists/${gistId}').then((data) {
      Map m = JSON.decode(data);

      String description = m['description'];
      _logger.info('loaded gist ${gistId} (${description})');
      _setGistDescription(description);
      _setGistId(m['id'], m['html_url']);

      Map files = m['files'];

      String dart = _getFileContent(files, ['main.dart'],
          (f) => f.endsWith('.dart'));
      String html = _getFileContent(files, ['index.html', 'body.html']);
      String css = _getFileContent(files, ['styles.css', 'style.css']);

      context.dartSource = dart;
      context.htmlSource = html;
      context.cssSource = css;

      // Analyze and run it.
      Timer.run(() {
        _handleRun();
        _performAnalysis();
      });
    }).catchError((e) {
      // TODO: Display any errors - use a toast.

      print('Error loading gist ${gistId}.');
      print(e);
    });
  }

  Future _initModules() {
    modules.register(new CodepadModule());
    //modules.register(new MockAnalysisModule());
    modules.register(new ServerAnalysisModule());
    //modules.register(new MockCompilerModule());
    modules.register(new ServerCompilerModule());
    //modules.register(new AceModule());
    modules.register(new CodeMirrorModule());

    return modules.start();
  }

  void _initPlayground() {
    // TODO: Set up some automatic value bindings.
    DSplitter editorSplitter = new DSplitter(querySelector('#editor_split'));
    editorSplitter.onPositionChanged.listen((pos) {
      state['editor_split'] = pos;
      editor.resize();
    });
    if (state['editor_split'] != null) {
     editorSplitter.position = state['editor_split'];
    }

    DSplitter outputSplitter = new DSplitter(querySelector('#output_split'));
    outputSplitter.onPositionChanged.listen((pos) {
      state['output_split'] = pos;
    });
    if (state['output_split'] != null) {
      outputSplitter.position = state['output_split'];
    }

    // Set up the iframe.
    deps[ExecutionService] = new ExecutionServiceIFrame(_frame);
    executionService.onStdout.listen(_showOuput);
    executionService.onStderr.listen((m) => _showOuput(m, error: true));

    // Set up the editing area.
    editor = editorFactory.createFromElement(_editpanel);
    _editpanel.children.first.attributes['flex'] = '';
    editor.resize();

    // TODO: Add a real code completer here.
    //editorFactory.registerCompleter('dart', new DartCompleter());

    keys.bind('ctrl-s', _handleSave);
    keys.bind('ctrl-enter', _handleRun);
    keys.bind('f1', _handleHelp);

    _context = new PlaygroundContext(editor);
    deps[Context] = _context;

    _context.onHtmlDirty.listen((_) => htmlBusyLight.on());
    _context.onHtmlReconcile.listen((_) {
      executionService.replaceHtml(_context.htmlSource);
      htmlBusyLight.reset();
    });

    _context.onCssDirty.listen((_) => cssBusyLight.on());
    _context.onCssReconcile.listen((_) {
      executionService.replaceCss(_context.cssSource);
      cssBusyLight.reset();
    });

    _context.onDartDirty.listen((_) => dartBusyLight.on());
    _context.onDartReconcile.listen((_) => _performAnalysis());

    _finishedInit();
  }

  _finishedInit() {
    // Clear the splash.
    DSplash splash = new DSplash(querySelector('div.splash'));
    splash.hide();

    _router = new Router();
    _router.root.addRoute(name: 'home', defaultRoute: true, enter: showHome);
    _router.root.addRoute(name: 'gist', path: '/:gist', enter: showGist);
    _router.listen();
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

      ga.sendEvent('edit', name);
      _context.switchTo(name);
    });
  }

  List<Element> _getTabElements(Element element) =>
      element.querySelectorAll('a');

  void _handleRun() {
    ga.sendEvent('main', 'run');
    runbutton.disabled = true;

    _clearOutput();

    compilerService.compile(context.dartSource).then((CompilerResult result) {
      return executionService.execute(
          _context.htmlSource, _context.cssSource, result.output);
    }).catchError((e) {
      // TODO: Also display using a toast.
      _showOuput('Error compiling to JavaScript:\n${e}', error: true);
    }).whenComplete(() {
      runbutton.disabled = false;
    });
  }

  void _performAnalysis() {
    String source = _context.dartSource;
    Lines lines = new Lines(source);

    Future request = analysisService.analyze(source);

    _analysisRequest = request;

    request.then((AnalysisResults result) {
      // Discard if we requested another analysis.
      if (_analysisRequest != request) return;

      // Discard if the document has been mutated since we requested analysis.
      if (source != _context.dartSource) return;

      dartBusyLight.reset();


      _displayIssues(result.issues);

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
    }).catchError((e) {
      _context.dartDocument.setAnnotations([]);
      dartBusyLight.reset();
      _logger.severe(e);
    });
  }

  void _handleSave() {
    ga.sendEvent('main', 'save');
    // TODO:
    print('handleSave');
  }

  void _handleHelp() {
    if (context.focusedEditor == 'dart') {
      ga.sendEvent('main', 'help');

      String source = _context.dartSource;
      Position pos = editor.document.cursor;
      int offset = editor.document.indexFromPos(pos);

      // TODO: Show busy.
      analysisService.getDocumentation(source, offset).then((Map result) {
        if (result['description'] == null && result['dartdoc'] == null) {
          // TODO: Tell the user there were no results.

        } else {
          // TODO: Display this info
          print(result['description']);
        }
      });
    }
  }

  void _clearOutput() {
    _outputpanel.text = '';
  }

  void _showOuput(String message, {bool error: false}) {
    message = message + '\n';
    SpanElement span = new SpanElement();
    if (error) span.classes.add('errorOutput');
    span.text = message;
    _outputpanel.children.add(span);
    span.scrollIntoView(ScrollAlignment.BOTTOM);
  }

  void _handleSelectChanged(SelectElement select) {
    String value = select.value;

    if (_isLegalGistId(value)) {
      _router.go('gist', {'gist': value});
    }

    select.value = '0';
  }

  void _setGistDescription(String description) {
    Element e = querySelector('header .header-gist-name');
    e.text = description == null ? '' : description;
  }

  void _setGistId(String title, String url) {
    Element e = querySelector('header .header-gist-id');

    if (title == null || url == null) {
      e.text = '';
    } else {
      e.children.clear();

      AnchorElement a = new AnchorElement(href: url);
      a.text = title;
      a.target = 'gist';
      e.children.add(a);
    }
  }

  void _displayIssues(List<AnalysisIssue> issues) {
    Element issuesElement = querySelector('#issues');

    // Detect when hiding; don't remove the content until hidden.
    bool isHiding = issuesElement.children.isNotEmpty && issues.isEmpty;

    if (isHiding) {
      issuesElement.classes.toggle('showing', issues.isNotEmpty);

      StreamSubscription sub;
      sub = issuesElement.onTransitionEnd.listen((_) {
        issuesElement.children.clear();
        sub.cancel();
      });
    } else {
      issuesElement.children.clear();

      issues.sort((a, b) => a.charStart - b.charStart);

      // Create an item for each issue.
      for (AnalysisIssue issue in issues) {
        DivElement e = new DivElement();
        e.classes.add('issue');
        issuesElement.children.add(e);
        e.onClick.listen((_) {
          _jumpTo(issue.line, issue.charStart, issue.charLength, focus: true);
        });

        SpanElement typeSpan = new SpanElement();
        typeSpan.classes.addAll([issue.kind, 'issuelabel']);
        typeSpan.text = issue.kind;
        e.children.add(typeSpan);

        SpanElement messageSpan = new SpanElement();
        messageSpan.classes.add('message');
        messageSpan.text = issue.message;
        e.children.add(messageSpan);
      }

      issuesElement.classes.toggle('showing', issues.isNotEmpty);
    }
  }

  void _jumpTo(int line, int charStart, int charLength, {bool focus: false}) {
    Document doc = editor.document;

    doc.select(
        doc.posFromIndex(charStart),
        doc.posFromIndex(charStart + charLength));

    if (focus) editor.focus();
  }
}

class PlaygroundContext extends Context {
  final Editor editor;

  Document _dartDoc;
  Document _htmlDoc;
  Document _cssDoc;

  StreamController _cssDirtyController = new StreamController.broadcast();
  StreamController _dartDirtyController = new StreamController.broadcast();
  StreamController _htmlDirtyController = new StreamController.broadcast();

  StreamController _cssReconcileController = new StreamController.broadcast();
  StreamController _dartReconcileController = new StreamController.broadcast();
  StreamController _htmlReconcileController = new StreamController.broadcast();

  PlaygroundContext(this.editor) {
    editor.mode = 'dart';
    _dartDoc = editor.document;
    _htmlDoc = editor.createDocument(content: '', mode: 'html');
    _cssDoc = editor.createDocument(content: '', mode: 'css');

    _dartDoc.onChange.listen((_) => _dartDirtyController.add(null));
    _htmlDoc.onChange.listen((_) => _htmlDirtyController.add(null));
    _cssDoc.onChange.listen((_) => _cssDirtyController.add(null));

    _createReconciler(_cssDoc, _cssReconcileController, 250);
    _createReconciler(_dartDoc, _dartReconcileController, 1250);
    _createReconciler(_htmlDoc, _htmlReconcileController, 250);
  }

  Document get dartDocument => _dartDoc;

  String get dartSource => _dartDoc.value;
  set dartSource(String value) {
    _dartDoc.value = value;
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

  String get focusedEditor {
    if (editor.document == _htmlDoc) return 'html';
    if (editor.document == _cssDoc) return 'css';
    return 'dart';
  }

  Stream get onCssDirty => _cssDirtyController.stream;
  Stream get onDartDirty => _dartDirtyController.stream;
  Stream get onHtmlDirty => _htmlDirtyController.stream;

  Stream get onCssReconcile => _cssReconcileController.stream;
  Stream get onDartReconcile => _dartReconcileController.stream;
  Stream get onHtmlReconcile => _htmlReconcileController.stream;

  void markCssClean() => _cssDoc.markClean();
  void markDartClean() => _dartDoc.markClean();
  void markHtmlClean() => _htmlDoc.markClean();

  /**
   * Restore the focus to the last focused editor.
   */
  void focus() => editor.focus();

  void _createReconciler(Document doc, StreamController controller, int delay) {
    Timer timer;
    doc.onChange.listen((_) {
      if (timer != null) timer.cancel();
      timer = new Timer(new Duration(milliseconds: delay), () {
        controller.add(null);
      });
    });
  }
}

// TODO: For CodeMirror, we get a request each time the user hits a key when the
// completion popup is open. We need to cache the results when appropriate.

// TODO: We need to cancel completion requests if one is open when we get
// another.

class DartCompleter extends CodeCompleter {
  Future<List<Completion>> complete(Editor editor) {
    return new Future.value([
      new Completion('one'),
      new Completion('two'),
      new Completion('three')
    ]);
  }
}

/**
 * Find the best match for the given file names in the gist file info; return
 * the file content (or the empty string if no match is found).
 */
String _getFileContent(Map files, List<String> names, [Function matcher]) {
  for (String name in names) {
    if (files.containsKey(name)) {
      return files[name]['content'];
    }
  }

  if (matcher != null) {
    String name = files.keys.firstWhere(matcher, orElse: () => null);
    if (name != null) return files[name]['content'];
  }

  return '';
}

bool _isLegalGistId(String id) {
  final RegExp regex = new RegExp(r'^[0-9a-f]+$');
  return regex.hasMatch(id) && id.length >= 5 && id.length <= 22;
}
