// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library playground;

import 'dart:async';
import 'dart:html' hide Console;

import 'package:dart_pad/editing/editor_codemirror.dart';
import 'package:logging/logging.dart';
import 'package:mdc_web/mdc_web.dart';
import 'package:meta/meta.dart';
import 'package:route_hierarchical/client.dart';
import 'package:split/split.dart';

import 'completion.dart';
import 'context.dart';
import 'core/dependencies.dart';
import 'core/keys.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'documentation.dart';
import 'editing/editor.dart';
import 'elements/bind.dart';
import 'elements/elements.dart';
import 'elements/analysis_results_controller.dart';
import 'elements/button.dart';
import 'elements/console.dart';
import 'elements/counter.dart';
import 'elements/dialog.dart';
import 'util/keymap.dart';
import 'elements/material_tab_controller.dart';
import 'modules/codemirror_module.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'playground_context.dart';
import 'services/common.dart';
import 'services/dartservices.dart';
import 'services/execution_iframe.dart';
import 'sharing/editor_doc_property.dart';
import 'sharing/gist_file_property.dart';
import 'sharing/gists.dart';
import 'sharing/gist_storage.dart';
import 'sharing/mutable_gist.dart';
import 'src/ga.dart';
import 'src/util.dart';
import 'util/detect_flutter.dart';

const codeMirrorOptions = {
  'continueComments': {'continueLineComment': false},
  'autofocus': false,
  'autoCloseBrackets': true,
  'matchBrackets': true,
  'tabSize': 2,
  'lineWrapping': true,
  'indentUnit': 2,
  'cursorHeight': 0.85,
  'viewportMargin': 100,
  'extraKeys': {
    'Cmd-/': 'toggleComment',
    'Ctrl-/': 'toggleComment',
    'Tab': 'insertSoftTab'
  },
  'hintOptions': {'completeSingle': false},
  'scrollbarStyle': 'simple',
};

Playground get playground => _playground;

Playground _playground;

final Logger _logger = Logger('dartpad');

void init() {
  _playground = Playground();
}

class Playground implements GistContainer, GistController {
  final MutableGist editableGist = MutableGist(Gist());
  final GistStorage _gistStorage = GistStorage();
  MDCButton newButton;
  MDCButton resetButton;
  MDCButton formatButton;
  MDCButton samplesButton;
  MDCButton runButton;
  MDCButton editorConsoleTab;
  MDCButton editorDocsTab;
  MDCButton closePanelButton;
  MDCButton moreMenuButton;
  DElement editorPanelHeader;
  DElement editorPanelFooter;
  MDCMenu samplesMenu;
  MDCMenu moreMenu;
  Dialog dialog;
  NewPadDialog newPadDialog;
  DElement titleElement;
  MaterialTabController webLayoutTabController;
  DElement webTabBar;
  DElement webOutputLabel;

  Splitter splitter;
  Splitter rightSplitter;
  bool rightSplitterConfigured = false;
  TabExpandController tabExpandController;
  AnalysisResultsController analysisResultsController;

  DBusyLight busyLight;
  DBusyLight consoleBusyLight;

  Editor editor;
  PlaygroundContext _context;
  Future _analysisRequest;
  Layout _layout;

  // The last returned shared gist used to update the url.
  Gist _overrideNextRouteGist;
  DocHandler docHandler;

  Console _leftConsole;
  Console _rightConsole;
  Counter unreadConsoleCounter;

  Playground() {
    _initModules().then((_) {
      _initPlayground();
      _initDialogs();
      _initBusyLights();
      _initGistNameHeader();
      _initGistStorage();
      _initLayoutDetection();
      _initButtons();
      _initLabels();
      _initSamplesMenu();
      _initMoreMenu();
      _initSplitters();
      _initTabs();
      _initLayout();
      _initConsoles();
    });
  }

  DivElement get _editorHost => querySelector('#editor-host') as DivElement;

  DivElement get _rightConsoleElement =>
      querySelector('#right-output-panel') as DivElement;

  DivElement get _rightConsoleContentElement =>
      querySelector('#right-output-panel-content') as DivElement;

  DivElement get _leftConsoleElement =>
      querySelector('#left-output-panel') as DivElement;

  IFrameElement get _frame => querySelector('#frame') as IFrameElement;

  DivElement get _rightDocPanel =>
      querySelector('#right-doc-panel') as DivElement;

  DivElement get _rightDocContentElement =>
      querySelector('#right-doc-panel-content') as DivElement;

  DivElement get _leftDocPanel =>
      querySelector('#left-doc-panel') as DivElement;

  DivElement get _editorPanelHeader =>
      querySelector('#editor-panel-header') as DivElement;

  DivElement get _editorPanelFooter =>
      querySelector('#editor-panel-footer') as DivElement;

  bool get _isCompletionActive => editor.completionActive;

  void _initDialogs() {
    dialog = Dialog();
    newPadDialog = NewPadDialog();
  }

  void _initBusyLights() {
    busyLight = DBusyLight(querySelector('#dartbusy'));
    consoleBusyLight = DBusyLight(querySelector('#consolebusy'));
  }

  void _initGistNameHeader() {
    // Update the title on changes.
    titleElement = DElement(querySelector('header .header-gist-name'));
    bind(editableGist.property('description'), titleElement.textProperty);
  }

  void _initGistStorage() {
    // If there was a change, and the gist is dirty, write the gist's contents
    // to storage.
    debounceStream(mutableGist.onChanged, Duration(milliseconds: 100))
        .listen((_) {
      if (mutableGist.dirty) {
        _gistStorage.setStoredGist(mutableGist.createGist());
      }
    });
  }

  void _initLayoutDetection() {
    debounceStream(mutableGist.onChanged, Duration(milliseconds: 32))
        .listen((_) {
      if (hasFlutterContent(_context.dartSource)) {
        _changeLayout(Layout.flutter);
      } else if (hasHtmlContent(_context.dartSource)) {
        _changeLayout(Layout.html);
      } else {
        _changeLayout(Layout.dart);
      }
    });
  }

  void _initButtons() {
    newButton = MDCButton(querySelector('#new-button') as ButtonElement)
      ..onClick.listen((_) => _showCreateGistDialog());
    resetButton = MDCButton(querySelector('#reset-button') as ButtonElement)
      ..onClick.listen((_) => _showResetDialog());
    formatButton = MDCButton(querySelector('#format-button') as ButtonElement)
      ..onClick.listen((_) => _format());
    formatButton = MDCButton(querySelector('#install-button') as ButtonElement)
      ..onClick.listen((_) => _showInstallPage());
    samplesButton =
        MDCButton(querySelector('#samples-dropdown-button') as ButtonElement)
          ..onClick.listen((e) {
            samplesMenu.open = !samplesMenu.open;
          });

    runButton = MDCButton(querySelector('#run-button') as ButtonElement)
      ..onClick.listen((_) {
        _handleRun();
      });
    editorConsoleTab =
        MDCButton(querySelector('#editor-panel-console-tab') as ButtonElement);
    editorDocsTab =
        MDCButton(querySelector('#editor-panel-docs-tab') as ButtonElement);
    closePanelButton = MDCButton(
        querySelector('#editor-panel-close-button') as ButtonElement,
        isIcon: true);
    moreMenuButton = MDCButton(
        querySelector('#more-menu-button') as ButtonElement,
        isIcon: true)
      ..onClick.listen((_) {
        moreMenu.open = !moreMenu.open;
      });
    querySelector('#keyboard-button')
        .onClick
        .listen((_) => _showKeyboardDialog());
  }

  void _initLabels() {
    var webOutputLabelElement = querySelector('#web-output-label');
    if (webOutputLabelElement != null) {
      webOutputLabel = DElement(webOutputLabelElement);
    }
  }

  void _initSamplesMenu() {
    var element = querySelector('#samples-menu');

    var samples = [
      Sample('215ba63265350c02dfbd586dfd30b8c3', 'Hello World', Layout.dart),
      Sample('e93b969fed77325db0b848a85f1cf78e', 'Int to Double', Layout.dart),
      Sample('b60dc2fc7ea49acecb1fd2b57bf9be57', 'Mixins', Layout.dart),
      Sample('7d78af42d7b0aedfd92f00899f93561b', 'Fibonacci', Layout.dart),
      Sample('b6409e10de32b280b8938aa75364fa7b', 'Counter', Layout.flutter),
      Sample('b3ccb26497ac84895540185935ed5825', 'Sunflower', Layout.flutter),
      Sample('ecb28c29c646b7f38139b1e7f44129b7', 'Draggables & physics',
          Layout.flutter),
      Sample('40308e0a5f47acba46ba62f4d8be2bf4', 'Implicit animations',
          Layout.flutter),
    ];

    var listElement = UListElement()
      ..classes.add('mdc-list')
      ..attributes.addAll({
        'aria-hidden': 'true',
        'aria-orientation': 'vertical',
        'tabindex': '-1'
      });

    element.children.add(listElement);

    // Helper function to create LIElement with correct attributes and classes
    // for material-components-web
    LIElement _menuElement(Sample sample) {
      return LIElement()
        ..classes.add('mdc-list-item')
        ..attributes.addAll({'role': 'menuitem'})
        ..children.add(
          ImageElement()
            ..classes.add('mdc-list-item__graphic')
            ..src = 'pictures/logo_${_layoutToString(sample.layout)}.png',
        )
        ..children.add(
          SpanElement()
            ..classes.add('mdc-list-item__text')
            ..text = sample.name,
        );
    }

    for (var sample in samples) {
      listElement.children.add(_menuElement(sample));
    }

    samplesMenu = MDCMenu(element)
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(querySelector('#samples-dropdown-button'))
      ..hoistMenuToBody();

    samplesMenu.listen('MDCMenu:selected', (e) {
      var index = (e as CustomEvent).detail['index'] as int;
      var gistId = samples.elementAt(index).gistId;
      router.go('gist', {'gist': gistId});
    });
  }

  void _initMoreMenu() {
    moreMenu = MDCMenu(querySelector('#more-menu'))
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(querySelector('#more-menu-button'))
      ..hoistMenuToBody();
    moreMenu.listen('MDCMenu:selected', (e) {
      var idx = (e as CustomEvent).detail['index'] as int;
      switch (idx) {
        case 0:
          _showSharingPage();
          break;
        case 1:
          _showGitHubPage();
          break;
        case 2:
          _showDartDevPage();
          break;
        case 3:
          _showFlutterDevPage();
          break;
      }
    });
  }

  void _initSplitters() {
    var editorPanel = querySelector('#editor-panel');
    var outputPanel = querySelector('#output-panel');

    splitter = flexSplit(
      [editorPanel, outputPanel],
      horizontal: true,
      gutterSize: 6,
      sizes: [50, 50],
      minSize: [100, 100],
    );
  }

  void _initRightSplitter() {
    if (rightSplitterConfigured) {
      return;
    }

    var outputHost = querySelector('#right-output-panel');
    rightSplitter = flexSplit(
      [outputHost, _rightDocPanel],
      horizontal: false,
      gutterSize: 6,
      sizes: [50, 50],
      minSize: [100, 100],
    );
    rightSplitterConfigured = true;
  }

  void _disposeRightSplitter() {
    if (!rightSplitterConfigured) {
      // The right splitter might already be destroyed.
      return;
    }
    rightSplitter?.destroy();
    rightSplitterConfigured = false;
  }

  void _initOutputPanelTabs() {
    if (tabExpandController != null) {
      return;
    }

    tabExpandController = TabExpandController(
      consoleButton: editorConsoleTab,
      docsButton: editorDocsTab,
      closeButton: closePanelButton,
      docsElement: _leftDocPanel,
      consoleElement: _leftConsoleElement,
      topSplit: _editorHost,
      bottomSplit: _editorPanelFooter,
      unreadCounter: unreadConsoleCounter,
    );
  }

  void _disposeOutputPanelTabs() {
    tabExpandController?.dispose();
    tabExpandController = null;
  }

  void _initTabs() {
    webTabBar = DElement(querySelector('#web-tab-bar'));
    webLayoutTabController =
        MaterialTabController(MDCTabBar(webTabBar.element));
    for (var name in ['dart', 'html', 'css']) {
      webLayoutTabController.registerTab(
          TabElement(querySelector('#$name-tab'), name: name, onSelect: () {
        ga.sendEvent('edit', name);
        _context.switchTo(name);
      }));
    }
  }

  void _initLayout() {
    editorPanelHeader = DElement(_editorPanelHeader);
    editorPanelFooter = DElement(_editorPanelFooter);
    _changeLayout(Layout.dart);
  }

  void _initConsoles() {
    _leftConsole = Console(DElement(_leftConsoleElement));
    _rightConsole = Console(DElement(_rightConsoleContentElement));
    unreadConsoleCounter =
        Counter(querySelector('#unread-console-counter') as SpanElement);
  }

  Future<void> _initModules() async {
    var modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());
    modules.register(CodeMirrorModule());

    await modules.start();
  }

  void _initPlayground() {
    // Set up the iframe.
    deps[ExecutionService] = ExecutionServiceIFrame(_frame);
    executionService.onStdout.listen(_showOutput);
    executionService.onStderr.listen((m) => _showOutput(m, error: true));

    // Set up Google Analytics.
    deps[Analytics] = Analytics();

    // Set up the gist loader.
    deps[GistLoader] = GistLoader.defaultFilters();

    // Set up CodeMirror
    editor = (editorFactory as CodeMirrorFactory)
        .createFromElement(_editorHost, options: codeMirrorOptions)
          ..theme = 'darkpad'
          ..mode = 'dart';

    // set up key bindings
    keys.bind(['ctrl-s'], _handleSave, 'Save', hidden: true);
    keys.bind(['ctrl-enter'], _handleRun, 'Run');
    keys.bind(['f1'], () {
      ga.sendEvent('main', 'help');
      docHandler.generateDoc(_rightDocContentElement);
      docHandler.generateDoc(_leftDocPanel);
    }, 'Documentation');

    keys.bind(['alt-enter'], () {
      editor.showCompletions(onlyShowFixes: true);
    }, 'Quick fix');

    keys.bind(['ctrl-space', 'macctrl-space'], () {
      editor.showCompletions();
    }, 'Completion');

    keys.bind(['shift-ctrl-/', 'shift-macctrl-/'], () {
      _showKeyboardDialog();
    }, 'Keyboard Shortcuts');
    keys.bind(['shift-ctrl-f', 'shift-macctrl-f'], () {
      _format();
    }, 'Format');

    document.onKeyUp.listen((e) {
      if (editor.completionActive ||
          DocHandler.cursorKeys.contains(e.keyCode)) {
        docHandler.generateDoc(_rightDocContentElement);
        docHandler.generateDoc(_leftDocPanel);
      }
      _handleAutoCompletion(e);
    });

    _context = PlaygroundContext(editor);
    deps[Context] = _context;

    editorFactory.registerCompleter(
        'dart', DartCompleter(dartServices, _context.dartDocument));

    _context.onDartDirty.listen((_) => busyLight.on());
    _context.onDartReconcile.listen((_) => _performAnalysis());

    Property htmlFile =
        GistFileProperty(editableGist.getGistFile('index.html'));
    Property htmlDoc = EditorDocumentProperty(_context.htmlDocument, 'html');
    bind(htmlDoc, htmlFile);
    bind(htmlFile, htmlDoc);

    Property cssFile = GistFileProperty(editableGist.getGistFile('styles.css'));
    Property cssDoc = EditorDocumentProperty(_context.cssDocument, 'css');
    bind(cssDoc, cssFile);
    bind(cssFile, cssDoc);

    Property dartFile = GistFileProperty(editableGist.getGistFile('main.dart'));
    Property dartDoc = EditorDocumentProperty(_context.dartDocument, 'dart');
    bind(dartDoc, dartFile);
    bind(dartFile, dartDoc);

    // Listen for changes that would effect the documentation panel.
    editor.onMouseDown.listen((e) {
      // Delay to give codemirror time to process the mouse event.
      Timer.run(() {
        if (!_context.cursorPositionIsWhitespace()) {
          docHandler.generateDoc(_rightDocContentElement);
          docHandler.generateDoc(_leftDocPanel);
        }
      });
    });

    // Set up the router.
    deps[Router] = Router();
    router.root.addRoute(name: 'home', defaultRoute: true, enter: showHome);
    router.root.addRoute(
        name: 'dart',
        path: '/dart',
        defaultRoute: false,
        enter: (_) => showNew(Layout.dart));
    router.root.addRoute(
        name: 'html',
        path: '/html',
        defaultRoute: false,
        enter: (_) => showNew(Layout.html));
    router.root.addRoute(
        name: 'flutter',
        path: '/flutter',
        defaultRoute: false,
        enter: (_) => showNew(Layout.flutter));
    router.root.addRoute(name: 'gist', path: '/:gist', enter: showGist);
    router.listen();

    docHandler = DocHandler(editor, _context);

    dartServices.version().then((VersionResponse version) {
      // "Based on Dart SDK 2.4.0"
      var versionText = 'Based on Dart SDK ${version.sdkVersionFull}';
      querySelector('#dartpad-version').text = versionText;
    }).catchError((e) => null);

    analysisResultsController = AnalysisResultsController(
        DElement(querySelector('#issues')),
        DElement(querySelector('#issues-message')),
        DElement(querySelector('#issues-toggle')))
      ..onIssueClick.listen((issue) {
        _jumpTo(issue.line, issue.charStart, issue.charLength, focus: true);
      });

    _finishedInit();
  }

  void _finishedInit() {
    // Clear the splash.
    var splash = DSplash(querySelector('div.splash'));
    splash.hide();
  }

  final RegExp cssSymbolRegexp = RegExp(r'[A-Z]');

  void _handleAutoCompletion(KeyboardEvent e) {
    if (context.focusedEditor == 'dart' && editor.hasFocus) {
      if (e.keyCode == KeyCode.PERIOD) {
        editor.showCompletions(autoInvoked: true);
      }
    }

    if (!_isCompletionActive && editor.hasFocus) {
      if (context.focusedEditor == 'html') {
        if (printKeyEvent(e) == 'shift-,') {
          editor.showCompletions(autoInvoked: true);
        }
      } else if (context.focusedEditor == 'css') {
        if (cssSymbolRegexp.hasMatch(String.fromCharCode(e.keyCode))) {
          editor.showCompletions(autoInvoked: true);
        }
      }
    }
  }

  Future<void> showNew(Layout layout) async {
    var loadResult = _loadGist();

    // If no gist was loaded, use a new Dart gist.
    if (loadResult == LoadGistResult.none) {
      editableGist.setBackingGist(_createGist(layout));

      // Store the gist so that the same sample is loaded when the page is
      // refreshed.
      _gistStorage.setStoredGist(editableGist.createGist());

      _changeLayout(layout);
    } else {
      // If a Gist was loaded from storage or from a Gist, use the layout
      // detected by reading the code.
      _changeLayout(_detectLayout(editableGist.backingGist));
    }

    // Clear console output and update the layout if necessary.
    var url = Uri.parse(window.location.toString());
    _clearOutput();

    if (url.hasQuery && url.queryParameters['line'] != null) {
      _jumpToLine(int.parse(url.queryParameters['line']));
    }

    // Run asynchronously to wait for _context.dartSource to exist
    Timer.run(_performAnalysis);
  }

  Gist _createGist(Layout layout) {
    switch (layout) {
      case Layout.flutter:
        return createSampleFlutterGist();
      case Layout.html:
        return createSampleHtmlGist();
      default:
        return createSampleDartGist();
    }
  }

  Future<void> showHome(RouteEnterEvent event) async {
    await showNew(Layout.dart);
  }

  /// Loads the gist provided by the 'id' query parameter or stored in
  /// [GistStorage].
  LoadGistResult _loadGist() {
    var url = Uri.parse(window.location.toString());

    if (url.hasQuery &&
        url.queryParameters['id'] != null &&
        isLegalGistId(url.queryParameters['id'])) {
      _showGist(url.queryParameters['id']);
      return LoadGistResult.queryParameter;
    }

    if (_gistStorage.hasStoredGist && _gistStorage.storedId == null) {
      var blankGist = Gist();
      editableGist.setBackingGist(blankGist);

      var storedGist = _gistStorage.getStoredGist();

      // Set the editable gist's backing gist so that the route handler can
      // detect the project type.
      editableGist.setBackingGist(storedGist);

      editableGist.description = storedGist.description;
      for (var file in storedGist.files) {
        editableGist.getGistFile(file.name).content = file.content;
      }
      return LoadGistResult.storage;
    }

    return LoadGistResult.none;
  }

  void showGist(RouteEnterEvent event) {
    var gistId = event.parameters['gist'] as String;

    _clearOutput();

    if (!isLegalGistId(gistId)) {
      showHome(event);
      return;
    }

    _showGist(gistId);
  }

  void _showGist(String gistId) {
    // Don't auto-run if we're re-loading some unsaved edits; the gist might
    // have halting issues (#384).
    var loadedFromSaved = false;

    // When sharing, we have to pipe the returned (created) gist through the
    // routing library to update the url properly.
    if (_overrideNextRouteGist != null && _overrideNextRouteGist.id == gistId) {
      editableGist.setBackingGist(_overrideNextRouteGist);
      _overrideNextRouteGist = null;
      return;
    }

    _overrideNextRouteGist = null;

    gistLoader.loadGist(gistId).then((Gist gist) {
      editableGist.setBackingGist(gist);

      if (_gistStorage.hasStoredGist && _gistStorage.storedId == gistId) {
        loadedFromSaved = true;

        var storedGist = _gistStorage.getStoredGist();
        editableGist.description = storedGist.description;
        for (var file in storedGist.files) {
          editableGist.getGistFile(file.name).content = file.content;
        }
      }

      _clearOutput();

      _changeLayout(_detectLayout(gist));

      // Analyze and run it.
      Timer.run(() {
        _performAnalysis().then((bool result) {
          // Only auto-run if the static analysis comes back clean.
          if (result && !loadedFromSaved) {
            _handleRun();
          }
        }).catchError((e) => null);
      });
    }).catchError((e) {
      var message = 'Error loading gist $gistId.';
      _showSnackbar(message);
      _logger.severe('$message: $e');
    });
  }

  void _showKeyboardDialog() {
    dialog.showOk('Keyboard shortcuts', keyMapToHtml(keys.inverseBindings));
  }

  void _handleRun() async {
    ga.sendEvent('main', 'run');
    runButton.disabled = true;

    var compilationTimer = Stopwatch()..start();

    final compileRequest = CompileRequest()..source = context.dartSource;

    try {
      if (hasFlutterContent(_context.dartSource)) {
        final response = await dartServices
            .compileDDC(compileRequest)
            .timeout(longServiceCallTimeout);

        ga.sendTiming(
          'action-perf',
          'compilation-e2e',
          compilationTimer.elapsedMilliseconds,
        );

        _clearOutput();

        return executionService.execute(
          _context.htmlSource,
          _context.cssSource,
          response.result,
          modulesBaseUrl: response.modulesBaseUrl,
        );
      } else {
        final response = await dartServices
            .compile(compileRequest)
            .timeout(longServiceCallTimeout);

        ga.sendTiming(
          'action-perf',
          'compilation-e2e',
          compilationTimer.elapsedMilliseconds,
        );

        _clearOutput();

        return await executionService.execute(
          _context.htmlSource,
          _context.cssSource,
          response.result,
        );
      }
    } catch (e) {
      ga.sendException('${e.runtimeType}');
      final message = e is ApiRequestError ? e.message : '$e';
      _showSnackbar('Error compiling to JavaScript');
      _clearOutput();
      _showOutput('Error compiling to JavaScript:\n$message', error: true);
    } finally {
      runButton.disabled = false;
      webOutputLabel.setAttr('hidden');
    }
  }

  /// Perform static analysis of the source code. Return whether the code
  /// analyzed cleanly (had no errors or warnings).
  Future<bool> _performAnalysis() {
    var input = SourceRequest()..source = _context.dartSource;

    var lines = Lines(input.source);

    var request = dartServices.analyze(input).timeout(serviceCallTimeout);
    _analysisRequest = request;

    return request.then((AnalysisResults result) {
      // Discard if we requested another analysis.
      if (_analysisRequest != request) return false;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != _context.dartSource) return false;

      busyLight.reset();

      _displayIssues(result.issues);

      _context.dartDocument
          .setAnnotations(result.issues.map((AnalysisIssue issue) {
        var startLine = lines.getLineForOffset(issue.charStart);
        var endLine =
            lines.getLineForOffset(issue.charStart + issue.charLength);

        var start = Position(
            startLine, issue.charStart - lines.offsetForLine(startLine));
        var end = Position(
            endLine,
            issue.charStart +
                issue.charLength -
                lines.offsetForLine(startLine));

        return Annotation(issue.kind, issue.message, issue.line,
            start: start, end: end);
      }).toList());

      var hasErrors = result.issues.any((issue) => issue.kind == 'error');
      var hasWarnings = result.issues.any((issue) => issue.kind == 'warning');

      return hasErrors == false && hasWarnings == false;
    }).catchError((e) {
      if (e is! TimeoutException) {
        final message = e is ApiRequestError ? e.message : '$e';

        _displayIssues([
          AnalysisIssue()
            ..kind = 'error'
            ..line = 1
            ..message = message
        ]);
      } else {
        _logger.severe(e);
      }

      _context.dartDocument.setAnnotations([]);
      busyLight.reset();
    });
  }

  Future<void> _format() {
    var originalSource = _context.dartSource;
    var input = SourceRequest()..source = originalSource;
    formatButton.disabled = true;

    var request = dartServices.format(input).timeout(serviceCallTimeout);
    return request.then((FormatResponse result) {
      busyLight.reset();
      formatButton.disabled = false;

      if (result.newString == null || result.newString.isEmpty) {
        _logger.fine('Format returned null/empty result');
        return;
      }

      if (originalSource != result.newString) {
        editor.document.updateValue(result.newString);
        _showSnackbar('Format successful.');
      } else {
        _showSnackbar('No formatting changes.');
      }
    }).catchError((e) {
      busyLight.reset();
      formatButton.disabled = false;
      _logger.severe(e);
    });
  }

  void _handleSave() => ga.sendEvent('main', 'save');

  void _clearOutput() {
    _rightConsole.clear();
    _leftConsole.clear();
    unreadConsoleCounter.clear();
  }

  void _showOutput(String message, {bool error = false}) {
    _leftConsole.showOutput(message, error: error);
    _rightConsole.showOutput(message, error: error);

    // If there's no tabs visible or the console is not being displayed,
    // increment the counter
    if (tabExpandController == null ||
        tabExpandController?.state != TabState.console) {
      unreadConsoleCounter.increment();
    }
  }

  void _showSnackbar(String message) {
    var div = querySelector('.mdc-snackbar');
    var snackbar = MDCSnackbar(div)..labelText = message;
    snackbar.open();
  }

  Layout _detectLayout(Gist gist) {
    if (gist.hasWebContent()) {
      return Layout.html;
    } else if (gist.hasFlutterContent()) {
      return Layout.flutter;
    } else {
      return Layout.dart;
    }
  }

  void _changeLayout(Layout layout) {
    if (_layout == layout) {
      return;
    }

    _layout = layout;

    if (layout == Layout.dart) {
      _frame.hidden = true;
      editorPanelFooter.setAttr('hidden');
      _disposeOutputPanelTabs();
      _rightDocPanel.attributes.remove('hidden');
      _rightConsoleElement.attributes.remove('hidden');
      webTabBar.setAttr('hidden');
      webLayoutTabController.selectTab('dart');
      _initRightSplitter();
      editorPanelHeader.setAttr('hidden');
      webOutputLabel.setAttr('hidden');
    } else if (layout == Layout.html) {
      _disposeRightSplitter();
      _frame.hidden = false;
      editorPanelFooter.clearAttr('hidden');
      _initOutputPanelTabs();
      _rightDocPanel.setAttribute('hidden', '');
      _rightConsoleElement.setAttribute('hidden', '');
      webTabBar.toggleAttr('hidden', false);
      webLayoutTabController.selectTab('dart');
      editorPanelHeader.clearAttr('hidden');
      webOutputLabel.setAttr('hidden');
    } else if (layout == Layout.flutter) {
      _disposeRightSplitter();
      _frame.hidden = false;
      editorPanelFooter.clearAttr('hidden');
      _initOutputPanelTabs();
      _rightDocPanel.setAttribute('hidden', '');
      _rightConsoleElement.setAttribute('hidden', '');
      webTabBar.setAttr('hidden');
      webLayoutTabController.selectTab('dart');
      editorPanelHeader.setAttr('hidden');
      webOutputLabel.clearAttr('hidden');
    }
  }

  // GistContainer interface
  @override
  MutableGist get mutableGist => editableGist;

  @override
  void overrideNextRoute(Gist gist) {
    _overrideNextRouteGist = gist;
  }

  Future<void> _showCreateGistDialog() async {
    var result = await dialog.showOkCancel(
        'Create New Pad', 'Discard changes to the current pad?');
    if (result == DialogResult.ok) {
      var layout = await newPadDialog.show();
      await createGistForLayout(layout);
      _changeLayout(layout);
    }
  }

  Future<void> _showResetDialog() async {
    var result = await dialog.showOkCancel(
        'Reset Pad', 'Discard changes to the current pad?');
    if (result == DialogResult.ok) {
      _resetGists();
    }
  }

  void _showSharingPage() {
    window.location.href =
        'https://github.com/dart-lang/dart-pad/wiki/Sharing-Guide';
  }

  void _showGitHubPage() {
    window.location.href = 'https://github.com/dart-lang/dart-pad';
  }

  void _showDartDevPage() {
    window.location.href = 'https://dart.dev';
  }

  void _showFlutterDevPage() {
    window.location.href = 'https://flutter.dev';
  }

  void _showInstallPage() {

    if (_layout == Layout.dart) {
      ga?.sendEvent('main', 'install-dart');
      window.location.href = 'https://dart.dev/get-dart';
    } else {
      ga?.sendEvent('main', 'install-flutter');
      window.location.href = 'https://flutter.dev/get-started/install';
    }
  }

  @override
  Future<void> createNewGist() async {
    _gistStorage.clearStoredGist();

    if (ga != null) ga.sendEvent('main', 'new');

    _showSnackbar('New pad created');
    await router.go('gist', {'gist': ''}, forceReload: true);
  }

  Future<void> createGistForLayout(Layout layout) async {
    _gistStorage.clearStoredGist();

    if (ga != null) ga.sendEvent('main', 'new');

    _showSnackbar('New pad created');

    var layoutStr = _layoutToString(layout);

    await router.go(layoutStr, {}, forceReload: true);
  }

  void _resetGists() {
    _gistStorage.clearStoredGist();
    editableGist.reset();
    // Delay to give time for the model change event to propagate through
    // to the editor component (which is where `_performAnalysis()` pulls
    // the Dart source from).
    Timer.run(_performAnalysis);
    _clearOutput();
  }

  void _displayIssues(List<AnalysisIssue> issues) {
    analysisResultsController.display(issues);
  }

  void _jumpTo(int line, int charStart, int charLength, {bool focus = false}) {
    final doc = editor.document;

    doc.select(
        doc.posFromIndex(charStart), doc.posFromIndex(charStart + charLength));

    if (focus) editor.focus();
  }

  void _jumpToLine(int line) {
    final doc = editor.document;
    doc.select(Position(line, 0), Position(line, 0));

    editor.focus();
  }
}

enum LoadGistResult {
  storage,
  queryParameter,
  none,
}

enum Layout {
  flutter,
  dart,
  html,
}

String _layoutToString(Layout layout) {
  return layout.toString().split('.').last;
}

enum TabState {
  closed,
  docs,
  console,
}

/// Manages the bottom-left panel and tabs
class TabExpandController {
  final MDCButton consoleButton;
  final MDCButton docsButton;
  final MDCButton closeButton;
  final DElement console;
  final DElement docs;
  final Counter unreadCounter;

  /// The element to give the top half of the split when this panel
  /// opens
  final Element topSplit;

  /// The element to give the bottom half of the split
  final Element bottomSplit;

  final List<StreamSubscription> _subscriptions = [];

  TabState _state;
  Splitter _splitter;
  bool _splitterConfigured = false;

  TabState get state => _state;

  TabExpandController({
    @required this.consoleButton,
    @required this.docsButton,
    @required this.closeButton,
    @required Element consoleElement,
    @required Element docsElement,
    @required this.topSplit,
    @required this.bottomSplit,
    @required this.unreadCounter,
  })  : console = DElement(consoleElement),
        docs = DElement(docsElement) {
    _state = TabState.closed;
    console.setAttr('hidden');
    docs.setAttr('hidden');

    _subscriptions.add(consoleButton.onClick.listen((_) {
      toggleConsole();
    }));

    _subscriptions.add(docsButton.onClick.listen((_) {
      toggleDocs();
    }));

    _subscriptions.add(closeButton.onClick.listen((_) {
      _hidePanel();
    }));
  }

  void toggleConsole() {
    if (_state == TabState.closed) {
      _showConsole();
    } else if (_state == TabState.docs) {
      _showConsole();
      docs.setAttr('hidden');
      docsButton.toggleClass('active', false);
    } else if (_state == TabState.console) {
      _hidePanel();
    }
  }

  void toggleDocs() {
    if (_state == TabState.closed) {
      _showDocs();
    } else if (_state == TabState.console) {
      _showDocs();
      console.setAttr('hidden');
      consoleButton.toggleClass('active', false);
    } else if (_state == TabState.docs) {
      _hidePanel();
    }
  }

  void _showConsole() {
    unreadCounter.clear();
    _state = TabState.console;
    console.clearAttr('hidden');
    bottomSplit.classes.remove('border-top');
    consoleButton.toggleClass('active', true);
    _initSplitter();
    closeButton.toggleAttr('hidden', false);
  }

  void _hidePanel() {
    _destroySplitter();
    _state = TabState.closed;
    console.setAttr('hidden');
    docs.setAttr('hidden');
    bottomSplit.classes.add('border-top');
    consoleButton.toggleClass('active', false);
    docsButton.toggleClass('active', false);
    closeButton.toggleAttr('hidden', true);
  }

  void _showDocs() {
    _state = TabState.docs;
    docs.clearAttr('hidden');
    bottomSplit.classes.remove('border-top');
    docsButton.toggleClass('active', true);
    _initSplitter();
    closeButton.toggleAttr('hidden', false);
  }

  void _initSplitter() {
    if (_splitterConfigured) {
      return;
    }

    _splitter = flexSplit(
      [topSplit, bottomSplit],
      horizontal: false,
      gutterSize: 6,
      sizes: [70, 30],
      minSize: [100, 100],
    );
    _splitterConfigured = true;
  }

  void _destroySplitter() {
    if (!_splitterConfigured) {
      return;
    }

    _splitter?.destroy();
    _splitterConfigured = false;
  }

  void dispose() {
    bottomSplit.classes.add('border-top');
    _destroySplitter();

    // Reset selected tab
    docsButton.toggleClass('active', false);
    consoleButton.toggleClass('active', false);

    // Clear listeners
    _subscriptions.forEach((s) => s.cancel());
    _subscriptions.clear();
  }
}

class NewPadDialog {
  final MDCDialog _mdcDialog;
  final MDCRipple _dartButton;
  final MDCRipple _flutterButton;
  final MDCButton _createButton;
  final MDCButton _cancelButton;
  final MDCSwitch _htmlSwitch;
  final DElement _htmlSwitchContainer;

  NewPadDialog()
      : assert(querySelector('#new-pad-dialog') != null),
        assert(querySelector('#new-pad-select-dart') != null),
        assert(querySelector('#new-pad-select-flutter') != null),
        assert(querySelector('#new-pad-cancel-button') != null),
        assert(querySelector('#new-pad-create-button') != null),
        assert(querySelector('#new-pad-html-switch-container') != null),
        assert(querySelector('#new-pad-html-switch-container .mdc-switch') !=
            null),
        _mdcDialog = MDCDialog(querySelector('#new-pad-dialog')),
        _dartButton = MDCRipple(querySelector('#new-pad-select-dart')),
        _flutterButton = MDCRipple(querySelector('#new-pad-select-flutter')),
        _cancelButton =
            MDCButton(querySelector('#new-pad-cancel-button') as ButtonElement),
        _createButton =
            MDCButton(querySelector('#new-pad-create-button') as ButtonElement),
        _htmlSwitchContainer =
            DElement(querySelector('#new-pad-html-switch-container')),
        _htmlSwitch = MDCSwitch(
            querySelector('#new-pad-html-switch-container .mdc-switch'));

  Layout get selectedLayout {
    if (_dartButton.root.classes.contains('selected')) {
      return _htmlSwitch.checked ? Layout.html : Layout.dart;
    }

    if (_flutterButton.root.classes.contains('selected')) {
      return Layout.flutter;
    }

    return null;
  }

  Future<Layout> show() {
    _createButton.toggleAttr('disabled', true);

    var completer = Completer<Layout>();
    var dartSub = _dartButton.root.onClick.listen((_) {
      _flutterButton.root.classes.remove('selected');
      _dartButton.root.classes.add('selected');
      _createButton.toggleAttr('disabled', false);
      _htmlSwitchContainer.toggleClass('hide', false);
      _htmlSwitch.disabled = false;
    });

    var flutterSub = _flutterButton.root.onClick.listen((_) {
      _dartButton.root.classes.remove('selected');
      _flutterButton.root.classes.add('selected');
      _createButton.toggleAttr('disabled', false);
      _htmlSwitchContainer.toggleClass('hide', true);
    });

    var cancelSub = _cancelButton.onClick.listen((_) {
      completer.complete(null);
    });

    var createSub = _createButton.onClick.listen((_) {
      completer.complete(selectedLayout);
    });

    _mdcDialog.open();

    return completer.future.then((v) {
      _flutterButton.root.classes.remove('selected');
      _dartButton.root.classes.remove('selected');
      dartSub.cancel();
      flutterSub.cancel();
      cancelSub.cancel();
      createSub.cancel();
      _mdcDialog.close();
      return v;
    });
  }
}

class Sample {
  final String gistId;
  final String name;
  final Layout layout;

  Sample(this.gistId, this.name, this.layout);
}
