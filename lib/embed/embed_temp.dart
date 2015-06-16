// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.mobile_ui;

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
import '../src/util.dart';

PlaygroundMobile get playground => _playground;

PlaygroundMobile _playground;
Analytics ga = new Analytics();

Logger _logger = new Logger('mobile');

void init() {
  _playground = new PlaygroundMobile();
}

class PlaygroundMobile {
  PaperFab runButton;
  PaperIconButton exportButton;
  PaperIconButton cancelButton;
  PaperIconButton affirmButton;
  BusyLight dartBusyLight;

  Gist backupGist;
  
  Editor editor;
  PlaygroundContext _context;
  Future _analysisRequest;
  Router _router;

  PaperToast _resetToast;
  PaperToast _messageToast;
  PaperToast _errorsToast;
  PaperDialog _messageDialog;
  PaperDialog _resetDialog;
  PolymerElement _output;
  PaperProgress _editProgress;
  PaperProgress _runProgress;
  
  DivElement _docPanel; 
  DivElement _outputPanel;
  
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

    // TODO(devoncarew): Hack, until we resolve the issue with routing.
    String path = window.location.pathname;
    if (path.length > 2 && path.lastIndexOf('/') == 0) {
      String id = path.substring(1);
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

  void _createUi() {
    _messageToast = new PaperToast();
    document.body.children.add(_messageToast.element);
    
    _errorsToast = new PaperToast.from($('#errorToast'))
      ..duration = 100000;
    
    _resetToast = new PaperToast.from($('#resetToast'))
      ..duration = 3000;
    
    _messageDialog = new PaperDialog.from($("#messageDialog"));
    _resetDialog = new PaperDialog.from($("#resetDialog"));

    _docPanel = querySelector('#documentation');
    _outputPanel = querySelector('#frameContainer');
    
    //edit section
    PaperDrawerPanel topPanel = new PaperDrawerPanel.from($("paper-drawer-panel"));

    PaperMenu menu = new PaperMenu.from($("paper-menu"));
    menu.ironActivate.listen((_) {
      _router.go('gist', {'gist': menu.selectedName});
      topPanel.closeDrawer();
    });

    new PaperIconButton.from($('#nav-button'))
      ..onTap.listen((_) => topPanel.togglePanel());

    PolymerElement dropdownAnimation = new PolymerElement.from($("animated-dropdown"));

    new PaperIconButton.from($("#more-button"))..onTap.listen((e){
      $("#dropdown").style.top = ($("#more-button").getBoundingClientRect().top + 10).toString() + "px";
      $("#dropdown").style.left = ($("#more-button").getBoundingClientRect().left - 75).toString() + "px";
      dropdownAnimation.call("show");
    });

    new PaperItem.from($("#dartlang-item"))..onTap.listen((event) {
      event.preventDefault();
      window.open("https://www.dartlang.org/", "_blank");
      dropdownAnimation.call("hide");
    });

    new PaperItem.from($("#about-item"))..onTap.listen((event) {
      event.preventDefault();
      _showAboutDialog();
      dropdownAnimation.call("hide");
    });

    PaperTabs tabs = new PaperTabs.from($("paper-tabs"));
    tabs.ironSelect.listen((_) {
      String name = tabs.selectedName;
      ga.sendEvent('edit', name);
      _context.switchTo(name);
    });

    dartBusyLight = new BusyLight(tabs.element.children[0]);

    _editProgress = new PaperProgress.from($("#edit-progress"));
    runButton = new PaperFab.from($("#run-button"))
      ..onTap.listen((_) => _handleRun());

    // execute section
    /*new PaperFab.from($(".back-button"))
      ..onTap.listen((e)  {
      // for some reason e.stopPropagation is needed
      // otherwise the pages.selected will be "1"
      // TODO: we should probably report this bug to polymer
      e.stopPropagation();
    });*/

    exportButton = new PaperIconButton.from($('[icon="refresh"]'))
      ..onTap.listen((_) {
        _resetDialog.toggle();
    });
    
    cancelButton = new PaperIconButton.from($('#cancelButton'))
          ..onTap.listen((_) {
            _resetDialog.toggle();
    });
    
    affirmButton = new PaperIconButton.from($('#affirmButton'))
          ..onTap.listen((_) {
            _resetDialog.toggle();
            _reset();
    });
    
    _output = new PolymerElement.from($("#console"));
    
    
    PaperToggleButton toggleConsoleButton = new PaperToggleButton.from($("paper-toggle-button"));
    toggleConsoleButton.onIronChange.listen((_) {
      _docPanel.style.display = toggleConsoleButton.checked ? 'none' : 'block';
      _outputPanel.style.display = !toggleConsoleButton.checked ? 'none' : 'block';
    });
  
    _clearOutput();
  }

  void _reset() {
    _router = new Router()
      ..root.addRoute(name: 'home', defaultRoute: true, enter: showHome)
      ..root.addRoute(name: 'gist', path: '/:gist', enter: showGist)
      ..listen();
    _resetToast.show();
  }
  
  void _showGist(String gistId, {bool run: false}) {
    gistLoader.loadGist(gistId).then((Gist gist) {
      _setGistDescription(gist.description);
      _setGistId(gist.id);

      GistFile dart = chooseGistFile(gist, ['main.dart'], (f) => f.endsWith('.dart'));
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

  void _initPlayground() {
    // Set up the iframe.
    deps[ExecutionService] = new ExecutionServiceIFrame($('#frame'));
    executionService.onStdout.listen(_showOuput);
    executionService.onStderr.listen((m) => _showOuput(m, error: true));

    // Set up the editing area.
    editor = editorFactory.createFromElement($('#editpanel'));
    //$('editpanel').children.first.attributes['flex'] = '';
    editor.resize();

    // TODO: Add a real code completer here.
    //editorFactory.registerCompleter('dart', new DartCompleter());

    // Set up the gist loader.
    // TODO: Move to using the defaultFilters().
    deps[GistLoader] = new GistLoader();

    // QUESTION: Do we need these bindings for mobile ?
    // keys.bind(['ctrl-s'], _handleSave);
    // keys.bind(['ctrl-enter'], _handleRun);
    // keys.bind(['f1'], _handleHelp);

    document.onKeyUp.listen((e) {
      if (editor.completionActive ||
          DocHandler.cursorKeys.contains(e.keyCode)) {
        docHandler.generateDoc(_docPanel);
      }
    });
    
    // Listen for changes that would effect the documentation panel.
     editor.onMouseDown.listen((e) {
       // Delay to give codemirror time to process the mouse event.
       Timer.run(() {
         if (!_context.cursorPositionIsWhitespace()) {
           docHandler.generateDoc(_docPanel);
         }
       });
     });
    
    _context = new PlaygroundContext(editor);
    deps[Context] = _context;


    context.onModeChange.listen((_) => docHandler.generateDoc(_docPanel));
    
    _context.onHtmlReconcile.listen((_) {
      executionService.replaceHtml(_context.htmlSource);
    });

    _context.onCssReconcile.listen((_) {
      executionService.replaceCss(_context.cssSource);
    });

    _context.onDartDirty.listen((_) => dartBusyLight.on());
    _context.onDartReconcile.listen((_) => _performAnalysis());

    docHandler = new DocHandler(editor, _context);
    
    _finishedInit();
  }

  _finishedInit() {
    Timer.run(() {
      editor.resize();

      // Clear the splash.
      Element splash = querySelector('div.splash');
      splash.onTransitionEnd.listen((_) => splash.parent.children.remove(splash));
      splash.classes.toggle('hide', true);
    });

    _router = new Router()
      ..root.addRoute(name: 'home', defaultRoute: true, enter: showHome)
      ..root.addRoute(name: 'gist', path: '/:gist', enter: showGist)
      ..listen();
  }

  void _handleRun() {
    _clearOutput();
    ga.sendEvent('main', 'run');
    runButton.disabled = true;

    _editProgress.indeterminate = true;
    _editProgress.hidden(false);

    var input = new CompileRequest()..source = context.dartSource;
    dartServices.compile(input).timeout(longServiceCallTimeout).then(
        (CompileResponse response) {
      return executionService.execute(
          _context.htmlSource, _context.cssSource, response.result);
    }).catchError((e) {
      _showOuput('Error compiling to JavaScript:\n${e}', error: true);
      _showError('Error compiling to JavaScript', '${e}');
    }).whenComplete(() {
      runButton.disabled = false;
      _editProgress.hidden(true);
      _editProgress.indeterminate = false;
    });
  }

  void _performAnalysis() {
    var input = new SourceRequest()..source = _context.dartSource;
    Lines lines = new Lines(input.source);

    Future<AnalysisResults> request =
        dartServices.analyze(input).timeout(serviceCallTimeout);;

    _analysisRequest = request;

    request.then((AnalysisResults result) {
      // Discard if we requested another analysis.
      if (_analysisRequest != request) return;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != _context.dartSource) return;

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

  void _clearErrors() {
    _errorsToast.hide();
  }

  void _clearOutput() {
    _output.text = '';
    _output.add(new DivElement()
      ..text = 'Console output'
      ..classes.add('consoleTitle'));
  }

  void _showOuput(String message, {bool error: false}) {
    message = message + '\n';
    SpanElement span = new SpanElement();
    span.classes.add(error ? 'errorOutput' : 'normal');
    span.text = message;
    _output.add(span);
    span.scrollIntoView(ScrollAlignment.BOTTOM);
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
        doc.posFromIndex(charStart),
        doc.posFromIndex(charStart + charLength));

    if (focus) editor.focus();
  }

  void _showAboutDialog() {
    dartServices.version().timeout(new Duration(seconds: 2)).then(
        (VersionResponse ver) {
      _showAboutDialogWithVersion(version: ver.sdkVersion);
    }).catchError((e) {
      _showAboutDialogWithVersion();
    });
  }

  void _showAboutDialogWithVersion({String version}) {
    _messageDialog.element.querySelector('h2').text = 'About DartPad';
    String text = privacyText;
    if (version != null) text += " Based on Dart SDK ${version}.";
    _messageDialog.element.querySelector('p').setInnerHtml(text,
        validator: new PermissiveNodeValidator());
    _messageDialog.open();
  }

  void _showError(String title, String message) {
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
