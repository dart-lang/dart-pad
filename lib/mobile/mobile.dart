// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.mobile_ui;

import 'dart:async';
import 'dart:html' hide Document;

import 'package:dart_pad/dart_pad.dart';
import 'package:dart_pad/dartservices_client/v1.dart';
import 'package:dart_pad/context.dart';
import 'package:dart_pad/core/dependencies.dart';
import 'package:dart_pad/core/modules.dart';
import 'package:dart_pad/editing/editor.dart';
import 'package:dart_pad/modules/codemirror_module.dart';
import 'package:dart_pad/modules/dartservices_module.dart';
import 'package:dart_pad/modules/dart_pad_module.dart';
import 'package:dart_pad/services/common.dart';
import 'package:dart_pad/services/execution_iframe.dart';
import 'package:dart_pad/sharing/gists.dart';
import 'package:dart_pad/src/ga.dart';
import 'package:dart_pad/src/sample.dart' as sample;
import 'package:logging/logging.dart';
import 'package:route_hierarchical/client.dart';

import '../polymer/base.dart';
import '../polymer/core.dart';
import '../polymer/paper.dart';
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
  PaperIconButton rerunButton;

  BusyLight dartBusyLight;

  Editor editor;
  PlaygroundContext _context;
  Future _analysisRequest;
  Router _router;

  PaperToast _messageToast;
  PaperToast _errorsToast;
  PaperActionDialog _messageDialog;
  CoreElement _output;
  CoreAnimatedPages _pages;
  PaperProgress _editProgress;
  PaperProgress _runProgress;

  String _gistId;

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
    _pages = new CoreAnimatedPages()
      ..selected = '0'
      ..flex();
    Transitions.slideFromRight(_pages);
    document.body.children.add(_pages.element);

    _pages.add(_createEditSection(_pages));
    _pages.add(_createExecuteSection(_pages));

    _messageToast = new PaperToast();
    document.body.children.add(_messageToast.element);

    _errorsToast = new PaperToast()
      ..swipeDisabled = true
      ..autoCloseDisabled = true
      ..duration = 100000;
    document.body.children.add(_errorsToast.element);

    // TODO: use a dark theme?
    _messageDialog = new PaperActionDialog();
    PaperButton closeButton = new PaperButton(text: 'Close');
    _messageDialog.makeAffirmative(closeButton);
    _messageDialog.add(closeButton);
    Transition.coreTransitionCenter(_messageDialog);
    _messageDialog.add(CoreElement.p());
    document.body.children.add(_messageDialog.element);
  }

  CoreElement _createEditSection(CoreAnimatedPages pages) {
    CoreElement section = CoreElement.section();

    CoreDrawerPanel topPanel = new CoreDrawerPanel()..forceNarrow();
    section.add(topPanel);

    // drawer
    CoreHeaderPanel headerPanel = new CoreHeaderPanel();
    topPanel.makeDrawer(headerPanel);
    topPanel.add(headerPanel);
    CoreToolbar toolbar = new CoreToolbar()..id = 'nav-header';
    toolbar.add(CoreElement.span('Dart Pad'));
    headerPanel.add(toolbar);
    CoreMenu menu = new CoreMenu();
    _buildSamples(menu);
    menu.onCoreActivate.listen((_) => topPanel.closeDrawer());
    headerPanel.add(menu);

    // main
    CoreHeaderPanel mainPanel = new CoreHeaderPanel();
    topPanel.makeMain(mainPanel);
    topPanel.add(mainPanel);
    toolbar = new CoreToolbar()..id = 'main-header';
    PaperIconButton navButton = new PaperIconButton(icon: 'menu');
    navButton.onTap.listen((_) => topPanel.togglePanel());
    toolbar.add(navButton);
    toolbar.add(CoreElement.span()..clazz('sample-titles')..flex());

    // Overflow menu.
    PaperMenuButton overflowMenuButton = new PaperMenuButton();
    overflowMenuButton.add(new PaperIconButton(icon: 'more-vert'));
    PaperDropdown dropdown = new PaperDropdown()..halign = 'right';
    CoreMenu overflowMenu = new CoreMenu();
    overflowMenu.add(new PaperItem(text: 'About')..onTap.listen((event) {
      event.preventDefault();
      _showAboutDialog();
    }));
    dropdown.add(overflowMenu);
    overflowMenuButton.add(dropdown);
    toolbar.add(overflowMenuButton);

    CoreElement div = CoreElement.div()..clazz('bottom fit')..horizontal()..vertical();
    PaperTabs tabs = new PaperTabs()..flex();
    tabs.selected = '0';
    tabs.add(new PaperTab(name: 'dart', text: 'Dart'));
    tabs.add(new PaperTab(name: 'html', text: 'HTML'));
    tabs.add(new PaperTab(name: 'css', text: 'CSS'));

    dartBusyLight = new BusyLight(tabs.element.children[0]);

    div.add(tabs);
    toolbar.add(div);
    _editProgress = new PaperProgress()..clazz('bottom fit')..hidden();
    toolbar.add(_editProgress);

    mainPanel.add(toolbar);
    div = CoreElement.div()..fit()..id = 'editpanel'..clazz('editor');
    mainPanel.add(div);

    tabs.onCoreActivate.listen((_) {
      String name = tabs.selected;
      ga.sendEvent('edit', name);
      _context.switchTo(name);
    });

    runButton = new PaperFab(icon: 'av:play-arrow')..id = 'run-button';
    runButton.onClick.listen((_) => _handleRun());
    mainPanel.add(runButton);

    return section;
  }

  CoreElement _createExecuteSection(CoreAnimatedPages pages) {
    CoreElement section = CoreElement.section();

    CoreHeaderPanel header = new CoreHeaderPanel()..fit();
    section.add(header);

    CoreToolbar toolbar = new CoreToolbar();
    PaperFab backButton = new PaperFab(icon: 'arrow-back')
      ..clazz('back-button')
      ..mini = true;
    backButton.onTap.listen((_) {
      // TODO:
      pages.selected = '0';
      //window.history.back();
    });
    toolbar.add(backButton);
    toolbar.add(CoreElement.span()..clazz('sample-titles')..flex());
    PaperToggleButton toggleConsoleButton = new PaperToggleButton()..checked = true;
    toolbar.add(toggleConsoleButton);
    rerunButton = new PaperIconButton(icon: 'refresh');
    toolbar.add(rerunButton);
    _runProgress = new PaperProgress()..clazz('bottom fit')..hidden();
    toolbar.add(_runProgress);
    header.add(toolbar);

    rerunButton.onClick.listen((_) => _handleRerun());

    CoreElement content = CoreElement.div()..fit()..layout()..vertical();
    header.add(content);

    CoreElement frame = new CoreElement('iframe')
      ..flex(2)
      ..id = 'frame'
      ..setAttribute('sandbox', 'allow-scripts')
      ..setAttribute('src', 'frame.html');
    content.add(frame);
    _output = CoreElement.div()
      ..flex(1)
      ..clazz('console')
      ..element.style.height = '30%';
    content.add(_output);

    toggleConsoleButton.onCoreChange.listen((_) {
      _output.hidden(!toggleConsoleButton.checked);
    });

    return section;
  }

  void _showGist(String gistId, {bool run: false}) {
    Gist.loadGist(gistId).then((Gist gist) {
      _setGistDescription(gist.description);
      _setGistId(gist.id);

      GistFile dart = chooseGistFile(gist, ['main.dart'], (f) => f.endsWith('.dart'));
      GistFile html = chooseGistFile(gist, ['index.html', 'body.html']);
      GistFile css = chooseGistFile(gist, ['styles.css', 'style.css']);

      context.dartSource = dart == null ? '' : dart.content;
      context.htmlSource = html == null ? '' : extractHtmlBody(html.content);
      context.cssSource = css == null ? '' : css.content;

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
    deps[ExecutionService] = new ExecutionServiceIFrame($('frame'));
    executionService.onStdout.listen(_showOuput);
    executionService.onStderr.listen((m) => _showOuput(m, error: true));

    // Set up the editing area.
    editor = editorFactory.createFromElement($('editpanel'));
    //$('editpanel').children.first.attributes['flex'] = '';
    editor.resize();

    // TODO: Add a real code completer here.
    //editorFactory.registerCompleter('dart', new DartCompleter());

    keys.bind('ctrl-s', _handleSave);
    keys.bind('ctrl-enter', _handleRun);
    keys.bind('f1', _handleHelp);

    _context = new PlaygroundContext(editor);
    deps[Context] = _context;

    _context.onHtmlReconcile.listen((_) {
      executionService.replaceHtml(_context.htmlSource);
    });

    _context.onCssReconcile.listen((_) {
      executionService.replaceCss(_context.cssSource);
    });

    _context.onDartDirty.listen((_) => dartBusyLight.on());
    _context.onDartReconcile.listen((_) => _performAnalysis());

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

    _router = new Router();
    _router.root.addRoute(name: 'home', defaultRoute: true, enter: showHome);
    _router.root.addRoute(name: 'gist', path: '/:gist', enter: showGist);
    _router.listen();
  }

  void _handleRun() {
    ga.sendEvent('main', 'run');
    runButton.disabled = true;

    _editProgress.indeterminate = true;
    _editProgress.hidden(false);

    var input = new SourceRequest()..source = context.dartSource;
    dartServices.compile(input).timeout(longServiceCallTimeout)
    .then((CompileResponse response) {
      _clearOutput();

      // TODO: Use the router here instead -
      _pages.selected = '1';
      //_router.go('gist', {'gist': currentGistId()});

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

  void _handleRerun() {
    ga.sendEvent('main', 'rerun');
    rerunButton.disabled = true;

    _runProgress.indeterminate = true;
    _runProgress.hidden(false);

    var input = new SourceRequest()..source = context.dartSource;
    dartServices.compile(input).timeout(longServiceCallTimeout)
    .then((CompileResponse response) {
      _clearOutput();

      // TODO: Use the router here instead -
      _pages.selected = '1';
      //_router.go('gist', {'gist': currentGistId()});

      return executionService.execute(
          _context.htmlSource, _context.cssSource, response.result);
    }).catchError((e) {
      _showOuput('Error compiling to JavaScript:\n${e}', error: true);
      _showError('Error compiling to JavaScript', '${e}');
    }).whenComplete(() {
      rerunButton.disabled = false;
      _runProgress.hidden(true);
      _runProgress.indeterminate = false;
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

  void _handleSave() {
    ga.sendEvent('main', 'save');
    // TODO:
    print('handleSave');
  }

  void _handleHelp() {
    if (context.focusedEditor == 'dart') {
      ga.sendEvent('main', 'help');

//      String source = _context.dartSource;
//      Position pos = editor.document.cursor;
//      int offset = editor.document.indexFromPos(pos);

//      // TODO: Show busy.
//      dartServices.document(source, offset).then((Map result) {
//        if (result['description'] == null && result['dartdoc'] == null) {
//          // TODO: Tell the user there were no results.
//
//        } else {
//          // TODO: Display this info
//          print(result['description']);
//        }
//      });
    }
  }

  void _clearOutput() {
    _output.text = '';
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
      description = 'Dart Pad';
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
      _errorsToast.dismiss();
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

//  void _showMessage(String message) {
//    _messageToast.text = message;
//    _messageToast.show();
//  }

  void _showAboutDialog() {
    _messageDialog.heading = 'About Dart Pad';
    _messageDialog.element.querySelector('p').setInnerHtml(privacyText,
        validator: new PermissiveNodeValidator());
    _messageDialog.open();
  }

  void _showError(String title, String message) {
    _messageDialog.heading = title;
    _messageDialog.element.querySelector('p').text = message;
    _messageDialog.open();
  }

  String currentGistId() => _gistId;

  void _buildSamples(CoreMenu menu) {
    menu.add(new PaperItem(text: 'Bootstrap')..name('b51ea7c04322042b582a'));
    menu.add(new PaperItem(text: 'Clock')..name('83caa2b65236f8ebd703'));
    menu.add(new PaperItem(text: 'Fibonacci')..name('74e990d984faad26dea0'));
    menu.add(new PaperItem(text: 'Helloworld')..name('33706e19df021e52d98c'));
    menu.add(new PaperItem(text: 'Helloworld Html')..name('9126d5d48ebabf5bf547'));
    menu.add(new PaperItem(text: 'Solar')..name('72d83fe97bfc8e735607'));
    menu.add(new PaperItem(text: 'Spirodraw')..name('76d27117fd6313dd9167'));
    menu.add(new PaperItem(text: 'Sunflower')..name('9d2dd2ce17981ecacadd'));
    menu.add(new PaperItem(text: 'WebSockets')..name('479ecba5a56fd706b648'));

    menu.onCoreActivate.listen((e) {
      _router.go('gist', {'gist': menu.selected});
      menu.selected = '';
    });
  }
}

// TODO: create pages (dart / html / css)

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
