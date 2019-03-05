// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.embed_ui;

import 'dart:async';
import 'dart:html' hide Document;

import 'package:logging/logging.dart';
import 'package:route_hierarchical/client.dart';

import '../completion.dart';
import '../context.dart';
import '../core/dependencies.dart';
import '../core/keys.dart';
import '../core/modules.dart';
import '../dart_pad.dart';
import '../documentation.dart';
import '../editing/editor.dart';
import '../elements/elements.dart';
import '../modules/codemirror_module.dart';
import '../modules/dart_pad_module.dart';
import '../modules/dartservices_module.dart';
import '../polymer/base.dart';
import '../polymer/iron.dart';
import '../polymer/paper.dart';
import '../services/_dartpadsupportservices.dart';
import '../services/common.dart';
import '../services/dartservices.dart';
import '../services/execution_iframe.dart';
import '../sharing/gists.dart';
import '../src/ga.dart';
import '../src/sample.dart' as sample;

PlaygroundMobile get playground => _playground;

PlaygroundMobile _playground;
Analytics ga = Analytics();

Logger _logger = Logger('mobile');

void init() {
  _playground = PlaygroundMobile();
}

enum _FileType { dart, css, html }

class PlaygroundMobile {
  final String webURL = "https://dartpad.dartlang.org";

  PaperFab _runButton;
  PaperIconButton _exportButton;
  PaperIconButton _cancelButton;
  PaperIconButton _affirmButton;
  PaperIconButton _resetButton;
  PaperTabs _tabs;

  Map<_FileType, String> _lastRun;
  Router _router;

  CompileResponse _cachedCompile;
  Editor editor;
  PlaygroundContext _context;
  Future _analysisRequest;

  PaperToast _resetToast;
  PaperToast _messageToast;
  PaperToast _errorsToast;
  PaperDialog _messageDialog;
  PaperDialog _resetDialog;

  // PaperDialog _exportDialog;
  PolymerElement _output;
  PaperProgress _runProgress;

  DivElement _docPanel;

  DocHandler docHandler;
  String _gistId;

  bool get _isCompletionActive => editor.completionActive;

  PlaygroundMobile() {
    // Asynchronous processing to load UI faster in parallel
    Timer.run(() {
      _createUi();
    });
    Timer.run(() {
      _initModules().then((_) => _initPlayground());
    });
  }

  void showHome(RouteEnterEvent event) {
    _logger.info('routed to showHome, ${window.location}, ${event.parameters}');

    Uri url = Uri.parse(window.location.toString());
    if (url.hasQuery) {
      String id = url.queryParameters['id'];
      if (isLegalGistId(id)) {
        _showGist(id).then((_) {
          _storePreviousResult().then((_) {
            if (url.queryParameters['run'] == 'true') {
              _handleRun();
            }
          });
        });
        return;
      }
    }

    _clearErrors();
    _setGistDescription(null);
    _setGistId(null);

    context.dartSource = sample.dartCode;
    context.htmlSource = '\n';
    context.cssSource = '\n';
    _storePreviousResult();
  }

  void showGist(RouteEnterEvent event) {
    _logger.info('routed to showGist, ${window.location}, ${event.parameters}');

    String gistId = event.parameters['gist'];
    String page = event.parameters['page'];

    if (!isLegalGistId(gistId)) {
      showHome(event);
      return;
    }

    _showGist(gistId, run: page == 'run').then((_) {
      _storePreviousResult();
    });
  }

  void registerMessageToast() {
    _messageToast = PaperToast();
    document.body.children.add(_messageToast.element);
  }

  void registerErrorToast() {
    if ($('#errorToast') != null) {
      _errorsToast = PaperToast.from($('#errorToast'));
    } else {
      _errorsToast = PaperToast();
    }
    _errorsToast.duration = 1000000;
  }

  void registerResetToast() {
    if ($('#resetToast') != null) {
      _resetToast = PaperToast.from($('#resetToast'));
    } else {
      _resetToast = PaperToast();
    }
    _resetToast.duration = 3000;
  }

  void registerMessageDialog() {
    if ($("#messageDialog") != null) {
      _messageDialog = PaperDialog.from($("#messageDialog"));
    }
  }

  void registerResetDialog() {
    if ($("#resetDialog") != null) {
      _resetDialog = PaperDialog.from($("#resetDialog"));
    } else {
      _resetDialog = PaperDialog();
    }
  }

  void registerExportDialog() {
    /* if ($("#exportDialog") != null) {
      _exportDialog = new PaperDialog.from($("#exportDialog"));
    } else {
      _exportDialog = new PaperDialog();
    } */
  }

  void registerDocPanel() {
    if ($('#documentation') != null) {
      _docPanel = $('#documentation');

      // TODO: This should be done using encapsulation in the Polymer element.
      _docPanel.innerHtml =
          "<div class='default-text-div layout horizontal center-center'>"
          "<span class='default-text'>Documentation</span>"
          "</div>";
    } else {
      _docPanel = DivElement();
    }
  }

  void registerSelectorTabs() {
    if ($("#selector-tabs") != null) {
      _tabs = PaperTabs.from($("#selector-tabs"));
      _tabs.ironSelect.listen((_) {
        String name = _tabs.selectedName;
        ga.sendEvent('edit', name);
        _context.switchTo(name);
      });
    }
  }

  void registerEditProgress() {
    if ($("#run-progress") != null) {
      _runProgress = PaperProgress.from($("#run-progress"));
    }
  }

  void registerRunButton() {
    _runButton = PaperFab.from($("#run-button"));
    _runButton = _runButton != null ? _runButton : PaperFab();
    _runButton.clickAction(_handleRun);
  }

  void registerExportButton() {
    if ($('[icon="launch"]') != null) {
      _exportButton = PaperIconButton.from($('[icon="launch"]'));
      _exportButton.clickAction(() {
        // Sharing is currently disabled pending establishing OAuth2 configurations with Github.
        //_exportDialog.open();
        ga.sendEvent("embed", "export");

        if (_gistId == null) {
          window.open("/", "_export");
        } else {
          window.open("/$_gistId", "_export");
        }
      });
    }
  }

  void registerResetButton() {
    if ($('[icon="refresh"]') != null) {
      _resetButton = PaperIconButton.from($('[icon="refresh"]'));
      _resetButton.clickAction(() {
        _resetDialog.open();
        ga.sendEvent("embed", "reset");
      });
    }
  }

  void registerCancelRefreshButton() {
    if ($('#cancelButton') != null) {
      _cancelButton = PaperIconButton.from($('#cancelButton'));
      _cancelButton.clickAction(() {
        ga.sendEvent("embed", "resetCancel");
      });
    }
  }

  void registerAffirmRefreshButton() {
    if ($('#affirmButton') != null) {
      _affirmButton = PaperIconButton.from($('#affirmButton'));
      _affirmButton.clickAction(() {
        _reset();
      });
    }
  }

  void registerCancelExportButton() {
    if ($('#cancelExportButton') != null) {
      _cancelButton = PaperIconButton.from($('#cancelExportButton'));
      _cancelButton.clickAction(() {
        ga.sendEvent("embed", "exportCancel");
      });
    }
  }

  void registerAffirmExportButton() {
    if ($('#affirmExportButton') != null) {
      _affirmButton = PaperIconButton.from($('#affirmExportButton'));
      _affirmButton.clickAction(() {
        _export();
      });
    }
  }

  // Console must exist.
  void registerConsole() {
    _output = PolymerElement.from($("#console"));
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
    ga.sendEvent("embed", "exportAffirm");
    WindowBase exportWindow = window.open("", 'Export');
    PadSaveObject exportObject = PadSaveObject()
      ..html = context.htmlSource
      ..css = context.cssSource
      ..dart = context.dartSource;
    Future<UuidContainer> id = dartSupportServices.export(exportObject);
    id.then((UuidContainer container) {
      exportWindow.location.href =
          '$webURL/index.html?export=${container.uuid}';
    });
  }

  void _reset() {
    ga.sendEvent("embed", "resetAffirm");
    _router = Router();
    _router
      ..root.addRoute(name: 'home', defaultRoute: true, enter: showHome)
      ..root.addRoute(name: 'gist', path: '/:gist', enter: showGist)
      ..listen();
    _clearOutput();
  }

  Future<void> _showGist(String gistId, {bool run = false}) {
    return gistLoader.loadGist(gistId).then((Gist gist) {
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
      Uri url = Uri.parse(window.location.toString());
      if (url.hasQuery && url.queryParameters['line'] != null) {
        _jumpToLine(int.parse(url.queryParameters['line']));
      }
    }).catchError((e) {
      print('Error loading gist ${gistId}.\n${e}');
      _showError('Error Loading Gist', '${gistId} - ${e}');
    });
  }

  Future _initModules() {
    ModuleManager modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());
    modules.register(DartSupportServicesModule());
    modules.register(CodeMirrorModule());

    return modules.start();
  }

  void registerExecutionService() {
    if ($('#frame') != null) {
      deps[ExecutionService] = ExecutionServiceIFrame($('#frame'));
    } else {
      deps[ExecutionService] = ExecutionServiceIFrame(IFrameElement());
    }
  }

  // Sync toolbar ratios to splitters.
  void _syncToolbar() {
    if ($('#toolbarLeftPanel') != null) {
      $('#toolbarLeftPanel').style.width = $('#leftPanel').style.width;
    }
  }

  // Determine if the query parameters for splitter ratios are valid (0 to 100).
  bool validFlex(String input) {
    return input != null &&
        double.parse(input) > 0.0 &&
        double.parse(input) < 100.0;
  }

  int roundFlex(double flex) => (flex * 10.0).round();

  void removeFlex(Element e) {
    e.classes.removeWhere((elementClass) => elementClass.startsWith('flex-'));
  }

  void _initPlayground() {
    // Set up the iframe execution.
    registerExecutionService();
    executionService.onStdout.listen(_showOutput);
    executionService.onStderr.listen((m) => _showOutput(m, error: true));

    // Set up the editing area.
    editor = editorFactory.createFromElement($('#editpanel'));
    //$('editpanel').children.first.attributes['flex'] = '';
    editor.resize();

    // TODO: Add a real code completer here.
    //editorFactory.registerCompleter('dart', new DartCompleter());

    // Listen for changes that would effect the documentation panel.
    editor.onMouseDown.listen((e) {
      // Delay to give codemirror time to process the mouse event.
      Timer.run(() {
        if (!_context.cursorPositionIsWhitespace()) {
          docHandler.generateDocWithText(_docPanel);
        }
      });
    });

    _context = PlaygroundContext(editor);
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

    keys.bind(['alt-enter', 'ctrl-1'], () {
      editor.showCompletions(onlyShowFixes: true);
    }, "Quick fix");

    keys.bind(['ctrl-s'], _handleSave, "Save", hidden: true);

    keys.bind(['ctrl-space', 'macctrl-space'], () {
      editor.showCompletions();
    }, "Completion");

    document.onKeyUp.listen((e) {
      if (editor.completionActive ||
          DocHandler.cursorKeys.contains(e.keyCode)) {
        docHandler.generateDoc(_docPanel);
      }
      _handleAutoCompletion(e);
    });

    editorFactory.registerCompleter(
        'dart', DartCompleter(dartServices, _context._dartDoc));
    // Set up the gist loader.
    // TODO: Move to using the defaultFilters().
    deps[GistLoader] = GistLoader();

    document.onKeyUp.listen((e) {
      if (editor.completionActive ||
          DocHandler.cursorKeys.contains(e.keyCode)) {
        docHandler.generateDocWithText(_docPanel);
      }
    });
    docHandler = DocHandler(editor, _context);

    // Set up the splitters.
    Uri url = Uri.parse(window.location.toString());
    String v = url.queryParameters['verticalRatio'];
    String h = url.queryParameters['horizontalRatio'];
    num defaultVerticalRatio = 60;
    num defaultHorizontalRatio = 70;
    Element leftPanel = $('#leftPanel');
    Element rightPanel = $('#rightPanel');
    Element topPanel = $('#topPanel');
    Element bottomPanel = $('#bottomPanel');
    if (rightPanel != null && leftPanel != null) {
      num percent = validFlex(h) ? int.parse(h) : defaultVerticalRatio;
      leftPanel.style.width = '${percent}%';
      editor.resize();
      _syncToolbar();
    }
    if (topPanel != null && bottomPanel != null) {
      num percent = validFlex(v) ? int.parse(v) : defaultHorizontalRatio;
      topPanel.style.height = '${percent}%';
    }
    var disablePointerEvents = () {
      if ($("#frame") != null) $("#frame").style.pointerEvents = "none";
    };
    var enablePointerEvents = () {
      if ($("#frame") != null) $("#frame").style.pointerEvents = "inherit";
    };
    if ($('vertical-splitter') != null) {
      _syncToolbar();
      DSplitter verticalSplitter = DSplitter($('vertical-splitter'),
          onDragStart: disablePointerEvents, onDragEnd: enablePointerEvents);
      verticalSplitter.onPositionChanged.listen((pos) {
        editor.resize();
        _syncToolbar();
      });
    }
    if ($('horizontal-splitter') != null) {
      DSplitter($('horizontal-splitter'),
          onDragStart: disablePointerEvents, onDragEnd: enablePointerEvents);
    }

    _finishedInit();
  }

  void _finishedInit() {
    Timer.run(() {
      editor.resize();
    });
    _router = Router()
      ..root.addRoute(name: 'home', defaultRoute: true, enter: showHome)
      ..root.addRoute(name: 'gist', path: '/:gist', enter: showGist)
      ..listen();
  }

  final RegExp cssSymbolRegexp = RegExp(r"[A-Z]");

  void _handleAutoCompletion(KeyboardEvent e) {
    if (context.focusedEditor == 'dart' && editor.hasFocus) {
      if (e.keyCode == KeyCode.PERIOD) {
        editor.showCompletions(autoInvoked: true);
      }
    }

    if (!_isCompletionActive && editor.hasFocus) {
      if (context.focusedEditor == "html") {
        if (printKeyEvent(e) == "shift-,") {
          editor.showCompletions(autoInvoked: true);
        }
      } else if (context.focusedEditor == "css") {
        if (cssSymbolRegexp.hasMatch(String.fromCharCode(e.keyCode))) {
          editor.showCompletions(autoInvoked: true);
        }
      }
    }
  }

  void _handleSave() => ga.sendEvent('embed', 'save');

  void _handleRun() {
    _clearOutput();
    ga.sendEvent('embed', 'run');
    _runButton.disabled = true;

    if (_runProgress != null) {
      _runProgress.indeterminate = true;
      _runProgress.hidden(false);
    }

    if (_hasStoredRequest) {
      try {
        CompileResponse response = _cachedCompile;
        if (executionService != null) {
          executionService.execute(
              _context.htmlSource, _context.cssSource, response.result);
        }
      } catch (e) {
        _showOutput('Error compiling to JavaScript:\n${e}', error: true);
        _showError('Error compiling to JavaScript', '${e}');
      }
      _runButton.disabled = false;
      if (_runProgress != null) {
        _runProgress.hidden(true);
        _runProgress.indeterminate = false;
      }
      return;
    }

    var input = CompileRequest()..source = context.dartSource;
    _setLastRunCondition();
    _cachedCompile = null;
    dartServices
        .compile(input)
        .timeout(longServiceCallTimeout)
        .then((CompileResponse response) {
      _cachedCompile = response;
      if (executionService != null) {
        return executionService.execute(
            _context.htmlSource, _context.cssSource, response.result);
      }
    }).catchError((e) {
      _showOutput('Error compiling to JavaScript:\n${e}', error: true);
      _showError('Error compiling to JavaScript', '${e}');
    }).whenComplete(() {
      _runButton.disabled = false;
      if (_runProgress != null) {
        _runProgress.hidden(true);
        _runProgress.indeterminate = false;
      }
    });
  }

  bool get _hasStoredRequest {
    return (_lastRun != null &&
        _lastRun[_FileType.dart] == context.dartSource &&
        _lastRun[_FileType.html] == context.htmlSource &&
        _lastRun[_FileType.css] == context.cssSource &&
        _cachedCompile != null);
  }

  Future<void> _storePreviousResult() {
    var input = CompileRequest()..source = context.dartSource;
    _setLastRunCondition();
    return dartServices
        .compile(input)
        .timeout(longServiceCallTimeout)
        .then((CompileResponse response) {
      _cachedCompile = response;
    });
  }

  void _performAnalysis() {
    var input = SourceRequest()
      ..source = _context.dartSource
      ..strongMode = strongModeDefault;

    Lines lines = Lines(input.source);

    Future<AnalysisResults> request =
        dartServices.analyze(input).timeout(serviceCallTimeout);

    _analysisRequest = request;

    request.then((AnalysisResults result) {
      // Discard if we requested another analysis.
      if (_analysisRequest != request) return;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != _context.dartSource) return;

      _displayIssues(result.issues);

      _context.dartDocument
          .setAnnotations(result.issues.map((AnalysisIssue issue) {
        int startLine = lines.getLineForOffset(issue.charStart);
        int endLine =
            lines.getLineForOffset(issue.charStart + issue.charLength);

        Position start = Position(
            startLine, issue.charStart - lines.offsetForLine(startLine));
        Position end = Position(
            endLine,
            issue.charStart +
                issue.charLength -
                lines.offsetForLine(startLine));

        return Annotation(issue.kind, issue.message, issue.line,
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

    // TODO: This should be done using encapsulation in the Polymer element.
    _output.element.innerHtml =
        "<div class='consoleTitle default-text-div layout horizontal center-center'>"
        "<span class='default-text'>Console output</span>"
        "</div>";
  }

  void _showOutput(String message, {bool error = false}) {
    _pulsateConsole();
    if (message == null) return;
    Element title = $('.consoleTitle');
    if (title != null) title.hidden = true;
    message = '$message\n';
    SpanElement span = SpanElement();
    span.classes.add(error ? 'errorOutput' : 'normal');
    span.text = message;
    _output.add(span);
    _output.element.scrollTop = _output.element.scrollHeight;
  }

  Future _pulsateConsole() async {
    $('#bottomPanel').classes.add('pulsate');
    Timer(Duration(milliseconds: 1000), () {
      $('#bottomPanel').classes.remove('pulsate');
    });
  }

  void _setGistDescription(String description) {
    if (description == null || description.isEmpty) {
      description = 'DartPad';
    }

    for (Element e in querySelectorAll('.sample-titles')) {
      e.text = description == null ? '' : description;
    }
  }

  void _setLastRunCondition() {
    _lastRun = Map<_FileType, String>();
    _lastRun[_FileType.dart] = context.dartSource;
    _lastRun[_FileType.html] = context.htmlSource;
    _lastRun[_FileType.css] = context.cssSource;
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
      Element errorElement = _errorsToast.element;

      errorElement.children.clear();

      issues.sort((a, b) => a.charStart - b.charStart);

      // Create an item for each issue.
      for (AnalysisIssue issue in issues) {
        DivElement error = DivElement();
        error.classes.add('issue');
        error.classes.add('layout');
        error.classes.add('horizontal');
        errorElement.children.add(error);
        error.onClick.listen((_) {
          _jumpTo(issue.line, issue.charStart, issue.charLength, focus: true);
        });

        SpanElement typeSpan = SpanElement();
        typeSpan.classes.addAll([issue.kind, 'issuelabel']);
        typeSpan.text = issue.kind;
        error.children.add(typeSpan);

        SpanElement messageSpan = SpanElement();
        messageSpan.classes.add('message');
        messageSpan.classes.add('flex');
        messageSpan.text = issue.message;
        error.children.add(messageSpan);
        if (issue.hasFixes) {
          error.classes.add("hasFix");
          error.onClick.listen((e) {
            // This is a bit of a hack to make sure quick fixes popup
            // is only shown if the wrench is clicked,
            // and not if the text or label is clicked.
            if ((e.target as Element).className == "issue hasFix") {
              // codemiror only shows completions if there is no selected text
              _jumpTo(issue.line, issue.charStart, 0, focus: true);
              editor.showCompletions(onlyShowFixes: true);
            }
          });
        }
        errorElement.classes.toggle('showing', issues.isNotEmpty);
      }

      _errorsToast.show();
    }
  }

  void _jumpTo(int line, int charStart, int charLength, {bool focus = false}) {
    Document doc = editor.document;

    doc.select(
        doc.posFromIndex(charStart), doc.posFromIndex(charStart + charLength));

    if (focus) editor.focus();
  }

  void _jumpToLine(int line) {
    Document doc = editor.document;
    doc.select(Position(line, 0), Position(line, 0));
    editor.focus();
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

  final _modeController = StreamController<String>.broadcast();

  Document _dartDoc;
  Document _htmlDoc;
  Document _cssDoc;

  final _cssDirtyController = StreamController.broadcast();
  final _dartDirtyController = StreamController.broadcast();
  final _htmlDirtyController = StreamController.broadcast();

  final _cssReconcileController = StreamController.broadcast();
  final _dartReconcileController = StreamController.broadcast();
  final _htmlReconcileController = StreamController.broadcast();

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

    if (oldMode != name) {
      _modeController.add(name);
      focus();
    }
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

  /// Restore the focus to the last focused editor.
  void focus() => editor.focus();

  void _createReconciler(Document doc, StreamController controller, int delay) {
    Timer timer;
    doc.onChange.listen((_) {
      if (timer != null) timer.cancel();
      timer = Timer(Duration(milliseconds: delay), () {
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
