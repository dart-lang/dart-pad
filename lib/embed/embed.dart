// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

//Currently not in use

library dart_pad.embed_ui;

import 'dart:async';
import 'dart:html' hide Document;

import 'package:logging/logging.dart';
import 'package:route_hierarchical/client.dart';

import '../dart_pad.dart';
import '../documentation.dart';
import '../context.dart';
import '../core/dependencies.dart';
import '../core/modules.dart';
import '../editing/editor.dart';
import '../modules/codemirror_module.dart';
import '../modules/dartservices_module.dart';
import '../modules/dart_pad_module.dart';
import '../polymer/base.dart';
import '../polymer/iron.dart';
import '../polymer/paper.dart';
import '../services/common.dart';
import '../services/dartservices.dart';
import '../services/execution_iframe.dart';
import '../sharing/gists.dart';
import '../src/ga.dart';
import '../src/sample.dart' as sample;

PlaygroundMobile get playground => _playground;

PlaygroundMobile _playground;
Analytics ga = new Analytics();

Logger _logger = new Logger('mobile');

void init() {
  _playground = new PlaygroundMobile();
}

class PlaygroundMobile {
  PaperFab _runButton;
  PaperIconButton _exportButton;
  PaperIconButton _cancelButton;
  PaperIconButton _affirmButton;
  PaperIconButton _resetButton;
  PaperTabs _tabs;

  Gist backupGist;
  Router _router;

  Editor editor;
  PlaygroundContext _context;
  Future _analysisRequest;

  PaperToast _resetToast;
  PaperToast _messageToast;
  PaperToast _errorsToast;
  PaperDialog _messageDialog;
  PaperDialog _resetDialog;
  PaperDialog _exportDialog;
  PolymerElement _output;
  PaperProgress _editProgress;

  DivElement _docPanel;

  DocHandler docHandler;
  String _gistId;

  Future createNewGist() {
    return null;
  }

  ModuleManager modules = new ModuleManager();

  PlaygroundMobile() {
    _createUi();
    _initModules().then((_) => _initPlayground());
  }

  void showHome(RouteEnterEvent event) {
    _logger.info('routed to showHome, ${window.location}, ${event.parameters}');

    Uri url = Uri.parse(window.location.toString());
    if (url.hasQuery) {
      String id = url.queryParameters['id'];
      if (isLegalGistId(id)) {
        _showGist(id);
        return;
      }
    }

    _clearErrors();
    _setGistDescription(null);
    _setGistId(null);

    context.dartSource = sample.dartCode;
    context.htmlSource = sample.htmlCode;
    context.cssSource = sample.cssCode;
  }

  void showGist(RouteEnterEvent event) {
    _logger.info('routed to showGist, ${window.location}, ${event.parameters}');

    String gistId = event.parameters['gist'];
    String page = event.parameters['page'];

    if (!isLegalGistId(gistId)) {
      showHome(event);
      return;
    }

    _showGist(gistId, run: page == 'run');
  }

  void registerMessageToast() {
    _messageToast = new PaperToast();
    document.body.children.add(_messageToast.element);
  }

  void registerErrorToast() {
    if ($('#errorToast') != null) {
      _errorsToast = new PaperToast.from($('#errorToast'));
    } else {
      _errorsToast = new PaperToast();
    }
    _errorsToast.duration = 100000;
  }

  void registerResetToast() {
    if ($('#resetToast') != null) {
      _resetToast = new PaperToast.from($('#resetToast'));
    } else {
      _resetToast = new PaperToast();
    }
    _resetToast.duration = 3000;
  }

  void registerMessageDialog() {
    if ($("#messageDialog") != null) {
      _messageDialog = new PaperDialog.from($("#messageDialog"));
    }
  }

  void registerResetDialog() {
    if ($("#resetDialog") != null) {
      _resetDialog = new PaperDialog.from($("#resetDialog"));
    } else {
      _resetDialog = new PaperDialog();
    }
  }

  void registerExportDialog() {
    if ($("#exportDialog") != null) {
      _exportDialog = new PaperDialog.from($("#exportDialog"));
    } else {
      _exportDialog = new PaperDialog();
    }
  }

  void registerDocPanel() {
    if ($('#documentation') != null) {
      _docPanel = $('#documentation');
      _docPanel.innerHtml =
          "<div class='default-text-div layout horizontal center-center'><span class='default-text'>Documentation</span></div>";
    } else {
      _docPanel = new DivElement();
    }
  }

  void registerSelectorTabs() {
    if ($("#selector-tabs") != null) {
      _tabs = new PaperTabs.from($("#selector-tabs"));
      _tabs.ironSelect.listen((_) {
        String name = _tabs.selectedName;
        ga.sendEvent('edit', name);
        _context.switchTo(name);
      });
    }
  }

  void registerEditProgress() {
    if ($("#edit-progress") != null) {
      _editProgress = new PaperProgress.from($("#edit-progress"));
    }
  }

  void registerRunButton() {
    _runButton = new PaperFab.from($("#run-button"));
    _runButton = _runButton != null ? _runButton : new PaperFab();
    _runButton.onTap.listen((_) => _handleRun());
  }

  void registerExportButton() {
    if ($('[icon="launch"]') != null) {
      _exportButton = new PaperIconButton.from($('[icon="launch"]'));
      _exportButton.onTap.listen((_) {
        _exportDialog.toggle();
      });
    }
  }

  void registerResetButton() {
    if ($('[icon="refresh"]') != null) {
      _resetButton = new PaperIconButton.from($('[icon="refresh"]'));
      _resetButton.onTap.listen((_) {
        _resetDialog.toggle();
      });
    }
  }

  void registerCancelRefreshButton() {
    if ($('#cancelButton') != null) {
      _cancelButton = new PaperIconButton.from($('#cancelButton'));
      _cancelButton.onTap.listen((_) {
        _resetDialog.toggle();
      });
    }
  }

  void registerAffirmRefreshButton() {
    if ($('#affirmButton') != null) {
      _affirmButton = new PaperIconButton.from($('#affirmButton'));
      _affirmButton.onTap.listen((_) {
        _resetDialog.toggle();
        _reset();
      });
    }
  }

  void registerCancelExportButton() {
    if ($('#cancelButton') != null) {
      _cancelButton = new PaperIconButton.from($('#cancelExportButton'));
      _cancelButton.onTap.listen((_) {
        _exportDialog.toggle();
      });
    }
  }

  void registerAffirmExportButton() {
    if ($('#affirmButton') != null) {
      _affirmButton = new PaperIconButton.from($('#affirmExportButton'));
      _affirmButton.onTap.listen((_) {
        _exportDialog.toggle();
        _export();
      });
    }
  }

  //Console must exist
  void registerConsole() {
    _output = new PolymerElement.from($("#console"));
  }

  void _createUi() {
    registerMessageToast();
    registerErrorToast();
    registerResetToast();
    registerMessageDialog();
    registerResetDialog();
    registerExportDialog();
    registerDocPanel();
    registerSelectorTabs();
    registerEditProgress();
    registerRunButton();
    registerExportButton();
    registerResetButton();
    registerCancelRefreshButton();
    registerAffirmRefreshButton();
    registerCancelExportButton();
    registerAffirmExportButton();
    registerConsole();

    _clearOutput();
  }

  void _export() {
    window.open(
        "/index.html?dart=${Uri.encodeQueryComponent(context.dartSource)}&html=${Uri.encodeQueryComponent(context.htmlSource)}&css=${Uri.encodeQueryComponent(context.cssSource)}",
        "DartPad");
  }

  void _reset() {
    _router = new Router();
    _router
      ..root.addRoute(name: 'home', defaultRoute: true, enter: showHome)
      ..root.addRoute(name: 'gist', path: '/:gist', enter: showGist)
      ..listen();
  }

  void _showGist(String gistId, {bool run: false}) {
    gistLoader.loadGist(gistId).then((Gist gist) {
      _setGistDescription(gist.description);
      _setGistId(gist.id);

      GistFile dart =
          chooseGistFile(gist, ['main.dart'], (f) => f.endsWith('.dart'));
      GistFile html = chooseGistFile(gist, ['index.html', 'body.html']);
      GistFile css = chooseGistFile(gist, ['styles.css', 'style.css']);

      context.dartSource = dart == null ? '' : dart.content;
      context.htmlSource = html == null ? '' : extractHtmlBody(html.content);
      context.cssSource = css == null ? '' : css.content;

      _clearErrors();

      // Analyze and run it.
      Timer.run(() {
        _performAnalysis();
      });
    }).catchError((e) {
      print('Error loading gist ${gistId}.\n${e}');
      _showError('Error Loading Gist', '${gistId} - ${e}');
    });
  }

  Future _initModules() {
    modules.register(new DartPadModule());
    //modules.register(new MockAnalysisModule());
    //modules.register(new MockCompilerModule());
    modules.register(new DartServicesModule());
    //modules.register(new AceModule());
    modules.register(new CodeMirrorModule());

    return modules.start();
  }

  void registerExecutionService() {
    if ($('#frame') != null) {
      deps[ExecutionService] = new ExecutionServiceIFrame($('#frame'));
    } else {
      deps[ExecutionService] = new ExecutionServiceIFrame(new IFrameElement());
    }
  }

  bool validFlex(String input) {
    return input != null && double.parse(input) > 0.0 && double.parse(input) < 1.0;
  }
  
  int roundFlex(double flex) => (flex*10.0).round();
  
  
  void removeFlex(Element e) {
    e.classes.removeWhere((elementClass)=>elementClass.startsWith('flex-'));
  }
  
  void _initPlayground() {
    // Set up the iframe.execution
    registerExecutionService();
    executionService.onStdout.listen(_showOutput);
    executionService.onStderr.listen((m) => _showOutput(m, error: true));
    
    //Set up the splitters
    Uri url = Uri.parse(window.location.toString());
    String v = url.queryParameters['verticalRatio'];
    String h = url.queryParameters['horizontalRatio'];
    Element leftPanel = $('#leftPanel');
    Element rightPanel =$('#rightPanel');
    Element topPanel = $('#topPanel');
    Element bottomPanel = $('#bottomPanel');
    Element toolbarLeftPanel = $('#toolbarLeftPanel');
    Element toolbarRightPanel = $('#toolbarRightPanel');
    if (rightPanel != null && leftPanel != null && validFlex(h) != false) {
      removeFlex(leftPanel);
      removeFlex(rightPanel);
      int l = roundFlex(double.parse(h));
      leftPanel.classes.add('flex-${l}');
      rightPanel.classes.add('flex-${10-l}');
      if (toolbarRightPanel != null && toolbarLeftPanel != null) {
        removeFlex(toolbarLeftPanel);
        removeFlex(toolbarRightPanel);
        toolbarLeftPanel.classes.add('flex-${l}');
        toolbarRightPanel.classes.add('flex-${10-l}');
      }
    }
    if (topPanel != null && bottomPanel != null && validFlex(v) != false) {
      removeFlex(topPanel);
      removeFlex(bottomPanel);
      int t = roundFlex(double.parse(v));
      topPanel.classes.add('flex-${t}');
      bottomPanel.classes.add('flex-${10-t}');
    }
    
    // Set up the editing area.
    editor = editorFactory.createFromElement($('#editpanel'));
    //$('editpanel').children.first.attributes['flex'] = '';
    editor.resize();

    // TODO: Add a real code completer here.
    //editorFactory.registerCompleter('dart', new DartCompleter());

    // Set up the gist loader.
    // TODO: Move to using the defaultFilters().
    deps[GistLoader] = new GistLoader();

    document.onKeyUp.listen((e) {
      if (editor.completionActive ||
          DocHandler.cursorKeys.contains(e.keyCode)) {
        docHandler.generateDocWithText(_docPanel);
      }
    });

    // Listen for changes that would effect the documentation panel.
    editor.onMouseDown.listen((e) {
      // Delay to give codemirror time to process the mouse event.
      Timer.run(() {
        if (!_context.cursorPositionIsWhitespace()) {
          docHandler.generateDocWithText(_docPanel);
        }
      });
    });

    _context = new PlaygroundContext(editor);
    deps[Context] = _context;

    context.onModeChange
        .listen((_) => docHandler.generateDocWithText(_docPanel));

    _context.onHtmlReconcile.listen((_) {
      executionService.replaceHtml(_context.htmlSource);
    });

    _context.onCssReconcile.listen((_) {
      executionService.replaceCss(_context.cssSource);
    });

    _context.onDartReconcile.listen((_) => _performAnalysis());

    docHandler = new DocHandler(editor, _context);

    _finishedInit();
  }

  _finishedInit() {
    Timer.run(() {
      editor.resize();
    });

    _router = new Router()
      ..root.addRoute(name: 'home', defaultRoute: true, enter: showHome)
      ..root.addRoute(name: 'gist', path: '/:gist', enter: showGist)
      ..listen();
  }

  void _handleRun() {
    _clearOutput();
    ga.sendEvent('main', 'run');
    _runButton.disabled = true;

    if (_editProgress != null) {
      _editProgress.indeterminate = true;
      _editProgress.hidden(false);
    }

    var input = new CompileRequest()..source = context.dartSource;
    dartServices
        .compile(input)
        .timeout(longServiceCallTimeout)
        .then((CompileResponse response) {
      if (executionService != null) {
        return executionService.execute(
            _context.htmlSource, _context.cssSource, response.result);
      }
    }).catchError((e) {
      _showOutput('Error compiling to JavaScript:\n${e}', error: true);
      _showError('Error compiling to JavaScript', '${e}');
    }).whenComplete(() {
      _runButton.disabled = false;
      if (_editProgress != null) {
        _editProgress.hidden(true);
        _editProgress.indeterminate = false;
      }
    });
  }

  void _performAnalysis() {
    var input = new SourceRequest()..source = _context.dartSource;
    Lines lines = new Lines(input.source);

    Future<AnalysisResults> request =
        dartServices.analyze(input).timeout(serviceCallTimeout);
    ;

    _analysisRequest = request;

    request.then((AnalysisResults result) {
      // Discard if we requested another analysis.
      if (_analysisRequest != request) return;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != _context.dartSource) return;

      _displayIssues(result.issues);

      _context.dartDocument.setAnnotations(result.issues
          .map((AnalysisIssue issue) {
        int startLine = lines.getLineForOffset(issue.charStart);
        int endLine =
            lines.getLineForOffset(issue.charStart + issue.charLength);

        Position start = new Position(
            startLine, issue.charStart - lines.offsetForLine(startLine));
        Position end = new Position(endLine, issue.charStart +
            issue.charLength -
            lines.offsetForLine(startLine));

        return new Annotation(issue.kind, issue.message, issue.line,
            start: start, end: end);
      }).toList());
    }).catchError((e) {
      _context.dartDocument.setAnnotations([]);
      _logger.severe(e);
    });
  }

  void _clearErrors() {
    _errorsToast.hide();
  }

  void _clearOutput() {
    _output.text = '';
    _output.element.innerHtml =
        "<div class='consoleTitle default-text-div layout horizontal center-center'><span class='default-text'>Console output</span></div>";
  }

  void _showOutput(String message, {bool error: false}) {
    $('.consoleTitle').hidden = true;
    message = message + '\n';
    SpanElement span = new SpanElement();
    span.classes.add(error ? 'errorOutput' : 'normal');
    span.text = message;
    _output.add(span);
    span.scrollIntoView();
  }

  void _setGistDescription(String description) {
    if (description == null || description.isEmpty) {
      description = 'DartPad';
    }

    for (Element e in querySelectorAll('.sample-titles')) {
      e.text = description == null ? '' : description;
    }
  }

  void _setGistId(String id) {
    if (id == null || id.isEmpty) {
      _gistId = null;
    } else {
      _gistId = id;
    }
  }

  void _displayIssues(List<AnalysisIssue> issues) {
    if (issues.isEmpty) {
      _clearErrors();
    } else {
      Element element = _errorsToast.element;

      element.children.clear();

      issues.sort((a, b) => a.charStart - b.charStart);

      // Create an item for each issue.
      for (AnalysisIssue issue in issues) {
        DivElement e = new DivElement();
        e.classes.add('issue');
        element.children.add(e);
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

      _errorsToast.show();
    }
  }

  void _jumpTo(int line, int charStart, int charLength, {bool focus: false}) {
    Document doc = editor.document;

    doc.select(
        doc.posFromIndex(charStart), doc.posFromIndex(charStart + charLength));

    if (focus) editor.focus();
  }

  void _showError(String title, String message) {
    if (_messageDialog == null) {
      return;
    }
    _messageDialog.element.querySelector('h2').text = title;
    _messageDialog.element.querySelector('p').text = message;
    _messageDialog.open();
  }

  String currentGistId() => _gistId;
}

class PlaygroundContext extends Context {
  final Editor editor;

  StreamController<String> _modeController = new StreamController.broadcast();

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

  String get activeMode => editor.mode;

  Stream<String> get onModeChange => _modeController.stream;

  void switchTo(String name) {
    String oldMode = activeMode;

    if (name == 'dart') {
      editor.swapDocument(_dartDoc);
    } else if (name == 'html') {
      editor.swapDocument(_htmlDoc);
    } else if (name == 'css') {
      editor.swapDocument(_cssDoc);
    }

    if (oldMode != name) _modeController.add(name);
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

  bool cursorPositionIsWhitespace() {
    Document document = editor.document;
    String str = document.value;
    int index = document.indexFromPos(document.cursor);
    if (index < 0 || index >= str.length) return false;
    String char = str[index];
    return char != char.trim();
  }
}

/**
 * A simple element that can display a lightbulb, with fade in and out and a
 * built in counter.
 */
class BusyLight {
  static final Duration _delay = const Duration(milliseconds: 150);

  final Element element;
  int _count = 0;

  BusyLight(this.element);

  void on() {
    _count++;
    _reconcile();
  }

  void off() {
    _count--;
    if (_count < 0) _count = 0;
    _reconcile();
  }

  void flash() {
    on();
    new Future.delayed(_delay, off);
  }

  void reset() {
    _count = 0;
    _reconcile();
  }

  _reconcile() => element.classes.toggle('busy', _count > 0);
}
