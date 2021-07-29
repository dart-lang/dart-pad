// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library playground;

import 'dart:async';
import 'dart:html' hide Console;

import 'package:dart_pad/editing/editor_codemirror.dart';
import 'package:logging/logging.dart';
import 'package:mdc_web/mdc_web.dart';
import 'package:split/split.dart';
import 'package:stream_transform/stream_transform.dart';

import 'check_localstorage.dart';
import 'completion.dart';
import 'context.dart';
import 'core/dependencies.dart';
import 'core/keys.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'documentation.dart';
import 'editing/codemirror_options.dart';
import 'elements/analysis_results_controller.dart';
import 'elements/bind.dart';
import 'elements/button.dart';
import 'elements/console.dart';
import 'elements/counter.dart';
import 'elements/dialog.dart';
import 'elements/elements.dart';
import 'elements/material_tab_controller.dart';
import 'elements/tab_expand_controller.dart';
import 'modules/codemirror_module.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'playground_context.dart';
import 'services/common.dart';
import 'services/dartservices.dart';
import 'services/execution_iframe.dart';
import 'sharing/editor_doc_property.dart';
import 'sharing/editor_ui.dart';
import 'sharing/gist_file_property.dart';
import 'sharing/gist_storage.dart';
import 'sharing/gists.dart';
import 'sharing/mutable_gist.dart';
import 'src/ga.dart';
import 'util/detect_flutter.dart';
import 'util/query_params.dart' show queryParams;

Playground? get playground => _playground;

Playground? _playground;

final Logger _logger = Logger('dartpad');

void init() {
  _playground = Playground();
}

class Playground extends EditorUi implements GistContainer, GistController {
  final MutableGist editableGist = MutableGist(Gist());
  late GistStorage _gistStorage;
  late MDCButton newButton;
  late MDCButton resetButton;
  late MDCButton formatButton;
  late MDCButton installButton;
  late MDCButton samplesButton;
  late MDCButton editorConsoleTab;
  late MDCButton editorDocsTab;
  late MDCButton closePanelButton;
  late MDCButton moreMenuButton;
  late DElement editorPanelHeader;
  late DElement editorPanelFooter;
  late MDCMenu samplesMenu;
  late MDCMenu moreMenu;
  late NewPadDialog newPadDialog;
  late DElement titleElement;
  late MaterialTabController webLayoutTabController;
  late DElement webTabBar;
  late DElement webOutputLabel;
  late MDCSwitch nullSafetySwitch;

  late Splitter splitter;
  late Splitter rightSplitter;
  bool rightSplitterConfigured = false;
  TabExpandController? tabExpandController;

  @override
  late PlaygroundContext context;
  Layout? _layout;

  // The last returned shared gist used to update the url.
  Gist? _overrideNextRouteGist;
  late DocHandler docHandler;

  late Console _leftConsole;
  late Console _rightConsole;
  late Counter unreadConsoleCounter;

  Playground() {
    _initDialogs();
    _checkLocalStorage();
    _initModules().then((_) {
      _gistStorage = GistStorage();
      _initPlayground();
      _initBusyLights();
      _initGistNameHeader();
      _initGistStorage();
      _initLayoutDetection();
      _initButtons();
      _initLabels();
      _initSamplesMenu(nullSafe: nullSafetyEnabled);
      _initMoreMenu();
      _initSplitters();
      _initTabs();
      _initLayout();
      _initConsoles();
    }).then((_) {
      showHome();
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
    newPadDialog = NewPadDialog();
  }

  void _initBusyLights() {
    busyLight = DBusyLight(querySelector('#dartbusy')!);
  }

  void _initGistNameHeader() {
    // Update the title on changes.
    titleElement = DElement(querySelector('header .header-gist-name')!);
    bind(editableGist.property('description'), titleElement.textProperty);
  }

  void _initGistStorage() {
    // If there was a change, and the gist is dirty, write the gist's contents
    // to storage.
    mutableGist.onChanged.debounce(Duration(milliseconds: 100)).listen((_) {
      if (mutableGist.dirty) {
        _gistStorage.setStoredGist(mutableGist.createGist());
      }
    });
  }

  void _initLayoutDetection() {
    mutableGist.onChanged.debounce(Duration(milliseconds: 32)).listen((_) {
      if (hasFlutterContent(context.dartSource)) {
        _changeLayout(Layout.flutter);
      } else if (hasHtmlContent(context.dartSource)) {
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
    installButton = MDCButton(querySelector('#install-button') as ButtonElement)
      ..onClick.listen((_) => _showInstallPage());
    samplesButton =
        MDCButton(querySelector('#samples-dropdown-button') as ButtonElement)
          ..onClick.listen((e) {
            samplesMenu.open = !samplesMenu.open!;
          });

    runButton = MDCButton(querySelector('#run-button') as ButtonElement)
      ..onClick.listen((_) {
        handleRun();
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
        moreMenu.open = !moreMenu.open!;
      });
    querySelector('#keyboard-button')
        ?.onClick
        .listen((_) => showKeyboardDialog());
    querySelector('#dartpad-package-versions')
        ?.onClick
        .listen((_) => showPackageVersionsDialog());

    // Query params have higher precedence than local storage
    if (queryParams.hasNullSafety) {
      nullSafetyEnabled = queryParams.nullSafety;
    } else if (window.localStorage.containsKey('null_safety')) {
      nullSafetyEnabled = window.localStorage['null_safety'] == 'true';
    } else {
      // Default to null safety
      nullSafetyEnabled = true;
    }

    nullSafetySwitch = MDCSwitch(querySelector('#null-safety-switch'))
      ..checked = nullSafetyEnabled
      ..listen('change', (event) {
        _handleNullSafetySwitched(nullSafetySwitch.checked!);
      });
    _handleNullSafetySwitched(nullSafetyEnabled);
  }

  void _initLabels() {
    var webOutputLabelElement = querySelector('#web-output-label');
    if (webOutputLabelElement != null) {
      webOutputLabel = DElement(webOutputLabelElement);
    }
  }

  void _initSamplesMenu({bool nullSafe = false}) {
    var element = querySelector('#samples-menu')!;
    element.children.clear();

    List<Sample> samples;
    if (nullSafe) {
      samples = [
        Sample('215ba63265350c02dfbd586dfd30b8c3', 'Hello World', Layout.dart),
        Sample(
            'e93b969fed77325db0b848a85f1cf78e', 'Int to Double', Layout.dart),
        Sample('b60dc2fc7ea49acecb1fd2b57bf9be57', 'Mixins', Layout.dart),
        Sample('7d78af42d7b0aedfd92f00899f93561b', 'Fibonacci', Layout.dart),
        Sample('1a28bdd9203250d3226cc25d512579ec', 'Counter', Layout.flutter),
        Sample('e0a2e942e85fde2cd39b2741ff0c49e5', 'Sunflower', Layout.flutter),
        Sample('5e28c5273c2c1a41d30bad9f9d11da56', 'Draggables & physics',
            Layout.flutter),
        Sample('289ecf8480ad005f01faeace70bd529a', 'Implicit animations',
            Layout.flutter),
      ];
    } else {
      samples = [
        Sample('215ba63265350c02dfbd586dfd30b8c3', 'Hello World', Layout.dart),
        Sample(
            'e93b969fed77325db0b848a85f1cf78e', 'Int to Double', Layout.dart),
        Sample('b60dc2fc7ea49acecb1fd2b57bf9be57', 'Mixins', Layout.dart),
        Sample('7d78af42d7b0aedfd92f00899f93561b', 'Fibonacci', Layout.dart),
        Sample('b6409e10de32b280b8938aa75364fa7b', 'Counter', Layout.flutter),
        Sample('b3ccb26497ac84895540185935ed5825', 'Sunflower', Layout.flutter),
        Sample('ecb28c29c646b7f38139b1e7f44129b7', 'Draggables & physics',
            Layout.flutter),
        Sample('40308e0a5f47acba46ba62f4d8be2bf4', 'Implicit animations',
            Layout.flutter),
      ];
    }

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
      ..setAnchorElement(querySelector('#samples-dropdown-button')!)
      ..hoistMenuToBody();

    samplesMenu.listen('MDCMenu:selected', (e) {
      var index = (e as CustomEvent).detail['index'] as int;
      var gistId = samples.elementAt(index).gistId;
      showGist(gistId);
    });
  }

  void _initMoreMenu() {
    moreMenu = MDCMenu(querySelector('#more-menu'))
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(querySelector('#more-menu-button')!)
      ..hoistMenuToBody();
    moreMenu.listen('MDCMenu:selected', (e) {
      var idx = (e as CustomEvent).detail['index'] as int?;
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
    var editorPanel = querySelector('#editor-panel')!;
    var outputPanel = querySelector('#output-panel');

    splitter = flexSplit(
      [editorPanel, outputPanel!],
      horizontal: true,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: const [100, 100],
    );

    listenForResize(editorPanel);
  }

  void _initRightSplitter() {
    if (rightSplitterConfigured) {
      return;
    }

    var outputHost = querySelector('#right-output-panel')!;
    rightSplitter = flexSplit(
      [outputHost, _rightDocPanel],
      horizontal: false,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: const [100, 100],
    );
    rightSplitterConfigured = true;

    listenForResize(outputHost);
  }

  void _disposeRightSplitter() {
    if (!rightSplitterConfigured) {
      // The right splitter might already be destroyed.
      return;
    }
    rightSplitter.destroy();
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
      editorUi: this,
    );
  }

  void _disposeOutputPanelTabs() {
    tabExpandController?.dispose();
    tabExpandController = null;
  }

  void _initTabs() {
    webTabBar = DElement(querySelector('#web-tab-bar')!);
    webLayoutTabController =
        MaterialTabController(MDCTabBar(webTabBar.element));
    for (var name in ['dart', 'html', 'css']) {
      webLayoutTabController.registerTab(
          TabElement(querySelector('#$name-tab')!, name: name, onSelect: () {
        ga.sendEvent('edit', name);
        context.switchTo(name);
      }));
    }
  }

  void _initLayout() {
    editorPanelHeader = DElement(_editorPanelHeader);
    editorPanelFooter = DElement(_editorPanelFooter);
  }

  void _initConsoles() {
    _leftConsole = Console(DElement(_leftConsoleElement));
    _rightConsole = Console(DElement(_rightConsoleContentElement));
    unreadConsoleCounter =
        Counter(querySelector('#unread-console-counter') as SpanElement);
  }

  void _checkLocalStorage() {
    if (!checkLocalStorage()) {
      dialog.showOk(
          'Missing browser features',
          'DartPad requires localStorage to be enabled. '
              'For more information, visit '
              '<a href="https://dart.dev/tools/dartpad/troubleshoot">'
              'dart.dev/tools/dartpad/troubleshoot</a>.');
    }
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
    executionService = ExecutionServiceIFrame(_frame);
    executionService.onStdout.listen(showOutput);
    executionService.onStderr.listen((m) => showOutput(m, error: true));

    // Set up Google Analytics.
    deps[Analytics] = Analytics();

    // Set up the gist loader.
    deps[GistLoader] = GistLoader.defaultFilters();

    // Set up CodeMirror
    editor = (editorFactory as CodeMirrorFactory)
        .createFromElement(_editorHost, options: codeMirrorOptions)
      ..theme = 'darkpad'
      ..mode = 'dart'
      ..showLineNumbers = true;

    initKeyBindings();

    context = PlaygroundContext(editor);
    deps[Context] = context;

    editorFactory.registerCompleter(
        'dart', DartCompleter(dartServices, context.dartDocument));

    context.onDartDirty.listen((_) => busyLight.on());
    context.onDartReconcile.listen((_) => performAnalysis());

    Property htmlFile =
        GistFileProperty(editableGist.getGistFile('index.html')!);
    Property htmlDoc = EditorDocumentProperty(context.htmlDocument, 'html');
    bind(htmlDoc, htmlFile);
    bind(htmlFile, htmlDoc);

    Property cssFile =
        GistFileProperty(editableGist.getGistFile('styles.css')!);
    Property cssDoc = EditorDocumentProperty(context.cssDocument, 'css');
    bind(cssDoc, cssFile);
    bind(cssFile, cssDoc);

    Property dartFile =
        GistFileProperty(editableGist.getGistFile('main.dart')!);
    Property dartDoc = EditorDocumentProperty(context.dartDocument, 'dart');
    bind(dartDoc, dartFile);
    bind(dartFile, dartDoc);

    // Listen for changes that would effect the documentation panel.
    editor.onMouseDown.listen((e) {
      // Delay to give codemirror time to process the mouse event.
      Timer.run(() {
        if (!context.cursorPositionIsWhitespace()) {
          docHandler.generateDoc([_rightDocContentElement, _leftDocPanel]);
        }
      });
    });

    docHandler = DocHandler(editor, context);

    updateVersions();

    analysisResultsController = AnalysisResultsController(
        DElement(querySelector('#issues')!),
        DElement(querySelector('#issues-message')!),
        DElement(querySelector('#issues-toggle')!))
      ..onItemClicked.listen((item) {
        _jumpTo(item.line, item.charStart, item.charLength, focus: true);
      });

    _finishedInit();
  }

  @override
  void initKeyBindings() {
    keys.bind(['ctrl-s'], _handleSave, 'Save', hidden: true);
    keys.bind(['f1'], () {
      ga.sendEvent('main', 'help');
      docHandler.generateDoc([_rightDocContentElement, _leftDocPanel]);
    }, 'Documentation');

    keys.bind(['alt-enter'], () {
      editor.showCompletions(onlyShowFixes: true);
    }, 'Quick fix');

    keys.bind(['ctrl-space', 'macctrl-space'], () {
      editor.showCompletions();
    }, 'Completion');

    keys.bind(['shift-ctrl-f', 'shift-macctrl-f'], () {
      _format();
    }, 'Format');

    document.onKeyUp.listen((e) {
      if (editor.completionActive ||
          DocHandler.cursorKeys.contains(e.keyCode)) {
        docHandler.generateDoc([_rightDocContentElement, _leftDocPanel]);
      }
      _handleAutoCompletion(e);
    });

    super.initKeyBindings();
  }

  void _finishedInit() {
    // Clear the splash.
    var splash = DSplash(querySelector('div.splash')!);
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
    }

    // Clear console output and update the layout if necessary.
    clearOutput();

    final line = queryParams.line;
    if (line != null) {
      _jumpToLine(line);
    }

    // Run asynchronously to wait for _context.dartSource to exist
    Timer.run(performAnalysis);
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

  Future<void> showHome() async {
    await showNew(Layout.dart);
  }

  /// Loads the gist provided by the 'id' query parameter or stored in
  /// [GistStorage].
  LoadGistResult _loadGist() {
    final gistId = queryParams.gistId;

    if (gistId != null && isLegalGistId(gistId)) {
      _showGist(gistId);
      return LoadGistResult.queryParameter;
    }

    if (_gistStorage.hasStoredGist && _gistStorage.storedId == null) {
      var blankGist = Gist();
      editableGist.setBackingGist(blankGist);

      var storedGist = _gistStorage.getStoredGist()!;

      // Set the editable gist's backing gist so that the route handler can
      // detect the project type.
      editableGist.setBackingGist(storedGist);

      editableGist.description = storedGist.description;
      for (var file in storedGist.files!) {
        editableGist.getGistFile(file.name)!.content = file.content;
      }
      return LoadGistResult.storage;
    }

    return LoadGistResult.none;
  }

  void showGist(String gistId) {
    clearOutput();

    if (!isLegalGistId(gistId)) {
      showHome();
      return;
    } else if (editableGist.backingGist!.id == gistId) {
      return;
    }

    _showGist(gistId);
    queryParams.gistId = gistId;
  }

  void _showGist(String gistId) {
    // Don't auto-run if we're re-loading some unsaved edits; the gist might
    // have halting issues (#384).
    var loadedFromSaved = false;

    // When sharing, we have to pipe the returned (created) gist through the
    // routing library to update the url properly.
    if (_overrideNextRouteGist != null &&
        _overrideNextRouteGist!.id == gistId) {
      editableGist.setBackingGist(_overrideNextRouteGist);
      _overrideNextRouteGist = null;
      return;
    }

    _overrideNextRouteGist = null;

    gistLoader.loadGist(gistId).then((Gist gist) {
      editableGist.setBackingGist(gist);

      if (_gistStorage.hasStoredGist && _gistStorage.storedId == gistId) {
        loadedFromSaved = true;

        var storedGist = _gistStorage.getStoredGist()!;
        editableGist.description = storedGist.description;
        for (var file in storedGist.files!) {
          editableGist.getGistFile(file.name)!.content = file.content;
        }
      }

      clearOutput();

      // Analyze and run it.
      Timer.run(() {
        performAnalysis().then((bool result) {
          // Only auto-run if the static analysis comes back clean.
          if (result && !loadedFromSaved) {
            handleRun();
          }
        }).catchError((e) => null);
      });
    }).catchError((e) {
      var message = 'Error loading gist $gistId.';
      showSnackbar(message);
      _logger.severe('$message: $e');
    });
  }

  @override
  Future<bool> handleRun() async {
    var success = await super.handleRun();
    if (success) {
      webOutputLabel.setAttr('hidden');
    }
    return success;
  }

  Future<void> _format() {
    var originalSource = context.dartSource;
    var input = SourceRequest()..source = originalSource;
    formatButton.disabled = true;

    var request = dartServices.format(input).timeout(serviceCallTimeout);
    return request.then((FormatResponse result) {
      busyLight.reset();
      formatButton.disabled = false;

      if (result.newString.isEmpty) {
        _logger.fine('Format returned null/empty result');
        return;
      }

      if (originalSource != result.newString) {
        editor.document.updateValue(result.newString);
        showSnackbar('Format successful.');
      } else {
        showSnackbar('No formatting changes.');
      }
    }).catchError((e) {
      busyLight.reset();
      formatButton.disabled = false;
      _logger.severe(e);
    });
  }

  @override
  bool get shouldCompileDDC => hasFlutterContent(context.dartSource);

  @override
  bool get shouldAddFirebaseJs => hasFirebaseContent(context.dartSource);

  void _handleSave() => ga.sendEvent('main', 'save');

  @override
  void clearOutput() {
    _rightConsole.clear();
    _leftConsole.clear();
    unreadConsoleCounter.clear();
  }

  @override
  void showOutput(String message, {bool error = false}) {
    _leftConsole.showOutput(message, error: error);
    _rightConsole.showOutput(message, error: error);

    // If there are no tabs visible or the console is not being displayed,
    // increment the counter.
    if (tabExpandController == null ||
        tabExpandController!.state != TabState.console) {
      unreadConsoleCounter.increment();
    }
  }

  void _changeLayout(Layout layout) {
    if (_layout == layout) {
      return;
    }

    _layout = layout;

    switch (layout) {
      case Layout.dart:
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
        break;
      case Layout.html:
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
        break;
      case Layout.flutter:
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
        break;
    }
  }

  void _handleNullSafetySwitched(bool enabled) {
    final api = deps[DartservicesApi] as DartservicesApi?;

    if (enabled) {
      api!.rootUrl = nullSafetyServerUrl;
      window.localStorage['null_safety'] = 'true';
      nullSafetyEnabled = true;
      nullSafetySwitch.root.title = 'Null safety is currently enabled';
    } else {
      api!.rootUrl = preNullSafetyServerUrl;
      window.localStorage['null_safety'] = 'false';
      nullSafetyEnabled = false;
      nullSafetySwitch.root.title = 'Null safety is currently disabled';
    }

    updateVersions();

    queryParams.nullSafety = enabled;

    performAnalysis();
    _initSamplesMenu(nullSafe: enabled);
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
      final layout = await newPadDialog.show();
      if (layout == null) return;
      await createGistForLayout(layout);
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
      ga.sendEvent('main', 'install-dart');
      window.location.href = 'https://dart.dev/get-dart';
    } else {
      ga.sendEvent('main', 'install-flutter');
      window.location.href = 'https://flutter.dev/get-started/install';
    }
  }

  @override
  Future<void> createNewGist() async {
    _gistStorage.clearStoredGist();

    ga.sendEvent('main', 'new');

    showSnackbar('New pad created');
  }

  Future<void> createGistForLayout(Layout layout) async {
    _gistStorage.clearStoredGist();

    ga.sendEvent('main', 'new');

    queryParams.gistId = '';

    await showNew(layout);
    showSnackbar('New pad created');
  }

  void _resetGists() {
    _gistStorage.clearStoredGist();
    editableGist.reset();
    // Delay to give time for the model change event to propagate through
    // to the editor component (which is where `_performAnalysis()` pulls
    // the Dart source from).
    Timer.run(performAnalysis);
    clearOutput();
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
        _mdcDialog = MDCDialog(querySelector('#new-pad-dialog')!),
        _dartButton = MDCRipple(querySelector('#new-pad-select-dart')!),
        _flutterButton = MDCRipple(querySelector('#new-pad-select-flutter')!),
        _cancelButton =
            MDCButton(querySelector('#new-pad-cancel-button') as ButtonElement),
        _createButton =
            MDCButton(querySelector('#new-pad-create-button') as ButtonElement),
        _htmlSwitchContainer =
            DElement(querySelector('#new-pad-html-switch-container')!),
        _htmlSwitch = MDCSwitch(
            querySelector('#new-pad-html-switch-container .mdc-switch'));

  Layout? get selectedLayout {
    if (_dartButton.root.classes.contains('selected')) {
      return _htmlSwitch.checked! ? Layout.html : Layout.dart;
    }

    if (_flutterButton.root.classes.contains('selected')) {
      return Layout.flutter;
    }

    return null;
  }

  Future<Layout?> show() {
    _createButton.toggleAttr('disabled', true);

    var completer = Completer<Layout?>();
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
      completer.complete(selectedLayout);
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
