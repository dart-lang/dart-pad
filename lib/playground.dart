// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library playground;

import 'dart:async';
import 'dart:convert' show json;
import 'dart:html' hide Console;
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
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
import 'editing/editor_codemirror.dart';
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
import 'search_controller.dart';
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

final Logger _logger = Logger('dartpad');

class Playground extends EditorUi implements GistContainer, GistController {
  final MutableGist _editableGist = MutableGist(Gist());
  final GistStorage _gistStorage = GistStorage();
  final MDCButton _consoleClearLeftButton = MDCButton(
      querySelector('#left-console-clear-button') as ButtonElement,
      isIcon: true);
  final MDCButton _formatButton =
      MDCButton(querySelector('#format-button') as ButtonElement);
  final MDCButton _editorConsoleTab =
      MDCButton(querySelector('#editor-panel-console-tab') as ButtonElement);
  final MDCButton _editorDocsTab =
      MDCButton(querySelector('#editor-panel-docs-tab') as ButtonElement);
  final MDCButton _closePanelButton = MDCButton(
      querySelector('#editor-panel-close-button') as ButtonElement,
      isIcon: true);
  final DElement _editorPanelHeader =
      DElement(querySelector('#editor-panel-header') as DivElement);
  final DElement _editorPanelFooter =
      DElement(querySelector('#editor-panel-footer') as DivElement);
  final NewPadDialog _newPadDialog = NewPadDialog();
  late final MDCMenu _samplesMenu = _buildSamplesMenu();
  final DElement _titleElement =
      DElement(querySelector('header .header-gist-name')!);
  late final MaterialTabController _webLayoutTabController = _buildTabs();
  final DElement _webTabBar = DElement(querySelector('#web-tab-bar')!);
  final DElement _webOutputLabel =
      DElement(querySelector('#web-output-label')!);
  MDCMenu? _channelsMenu;
  String? _gistIdInProgress;

  late final SearchController _searchController;
  late Splitter _rightSplitter;
  bool _rightSplitterConfigured = false;
  TabExpandController? _tabExpandController;
  late GitHubLoginController _githubController;

  @override
  late PlaygroundContext context;
  Layout? _layout;

  // The last returned shared gist used to update the url.
  Gist? _overrideNextRouteGist;
  late DocHandler _docHandler;

  final Console _leftConsole = Console(DElement(_leftConsoleElement));
  final Console _rightConsole = Console(DElement(_rightConsoleContentElement));
  final Counter _unreadConsoleCounter =
      Counter(querySelector('#unread-console-counter') as SpanElement);

  late final List<Channel> channels;

  static Future<Playground> initialize() async {
    await _initModules();
    return Playground._();
  }

  Playground._() {
    _checkLocalStorage();
    _initPlayground();
    _initBusyLights();
    _initGistNameHeader();
    _initGistStorage();
    _initLayoutDetection();
    _initButtons();
    _initMoreMenu();
    _initGitHubMenu();
    _initSplitters();
    _initChannelsMenu();

    window.console.log('window URL = ${window.location.href}');
    _githubController = GitHubLoginController( Uri.dataFromString(window.location.href) );

    showHome();
  }

  DivElement get _editorHost => querySelector('#editor-host') as DivElement;

  DivElement get _rightConsoleElement =>
      querySelector('#right-output-panel') as DivElement;

  static DivElement get _rightConsoleContentElement =>
      querySelector('#right-output-panel-content') as DivElement;

  static DivElement get _leftConsoleElement =>
      querySelector('#left-output-panel') as DivElement;

  IFrameElement get _frame => querySelector('#frame') as IFrameElement;

  DivElement get _rightDocPanel =>
      querySelector('#right-doc-panel') as DivElement;

  DivElement get _rightDocContentElement =>
      querySelector('#right-doc-panel-content') as DivElement;

  DivElement get _leftDocPanel =>
      querySelector('#left-doc-panel') as DivElement;

  ButtonElement get _samplesDropdownButton =>
      querySelector('#samples-dropdown-button') as ButtonElement;

  ButtonElement get _channelsDropdownButton =>
      querySelector('#channels-dropdown-button') as ButtonElement;

  bool get _isCompletionActive => editor.completionActive;

  void _initBusyLights() {
    busyLight = DBusyLight(querySelector('#dartbusy')!);
  }

  void _initGistNameHeader() {
    // Update the title on changes.

    bind(_editableGist.property('description'), _titleElement.textProperty);
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

  static void _toggleMenu(MDCMenu? menu) => menu?.open = !menu.open!;

  void _initButtons() {
    MDCButton(querySelector('#new-button') as ButtonElement)
        .onClick
        .listen((_) => _showCreateGistDialog());
    MDCButton(querySelector('#reset-button') as ButtonElement)
        .onClick
        .listen((_) => _showResetDialog());
    _formatButton.onClick.listen((_) => _format());
    _consoleClearLeftButton.onClick.listen((_) => clearOutput());
    MDCButton(querySelector('#right-console-clear-button') as ButtonElement,
            isIcon: true)
        .onClick
        .listen((_) => clearOutput());
    MDCButton(querySelector('#install-button') as ButtonElement)
        .onClick
        .listen((_) => _showInstallPage());

    MDCButton(_samplesDropdownButton)
        .onClick
        .listen((e) => _toggleMenu(_samplesMenu));

    runButton = MDCButton(querySelector('#run-button') as ButtonElement)
      ..onClick.listen((_) {
        handleRun();
      });
    querySelector('#keyboard-button')
        ?.onClick
        .listen((_) => showKeyboardDialog());
    querySelector('#dartpad-package-versions')
        ?.onClick
        .listen((_) => showPackageVersionsDialog());

    MDCButton(_channelsDropdownButton)
        .onClick
        .listen((e) => _toggleMenu(_channelsMenu));

    _searchController = SearchController(editorFactory, editor, snackbar);
  }

  MDCMenu _buildSamplesMenu() {
    final element = querySelector('#samples-menu')!;
    element.children.clear();

    const samples = [
      Sample('e75b493dae1287757c5e1d77a0dc73f1', 'Counter', Layout.flutter),
      Sample('5c0e154dd50af4a9ac856908061291bc', 'Sunflower', Layout.flutter),
      Sample('a1d5666d6b54a45eb170b897895cf757', 'Draggables & physics',
          Layout.flutter),
      Sample('85e77d36533b16647bf9b6eb8c03296d', 'Implicit animations',
          Layout.flutter),
      Sample('d57c6c898dabb8c6fb41018588b8cf73', 'Firebase Nanochat',
          Layout.flutter),
      Sample(
          '493c8b3ef8931cbac3fbbe5c04b9c4cf', 'Google Fonts', Layout.flutter),
      Sample('a133148221a8cbacbcef8bc77a6c82ec', 'Provider', Layout.flutter),
      Sample(
          'fdd369962f4ff6700a83c8a540fd6c4c', 'Flutter Bloc', Layout.flutter),
      Sample('c0f7c578204d61e08ec0fbc4d63456cd', 'Hello World', Layout.dart),
      Sample('d3bd83918d21b6d5f778bdc69c3d36d6', 'Fibonacci', Layout.dart),
      Sample('4a68e553746602d851ab3da6aeafc3dd', 'HTTP requests', Layout.dart),
    ];

    BuiltInSamplesList.addSamples( samples );

    final listElement = _mdcList();
    element.children.add(listElement);

    for (final sample in samples) {
      final menuElement = _mdcListItem(children: [
        ImageElement()
          ..classes.add('mdc-list-item__graphic')
          ..src = 'pictures/logo_${_layoutToString(sample.layout)}.png',
        SpanElement()
          ..classes.add('mdc-list-item__text')
          ..text = sample.name,
      ]);
      listElement.children.add(menuElement);
    }

    final samplesMenu = MDCMenu(element)
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(_samplesDropdownButton)
      ..hoistMenuToBody();

    samplesMenu.listen('MDCMenu:selected', (e) {
      final index = (e as CustomEvent).detail['index'] as int;
      final gistId = samples.elementAt(index).gistId;
      showGist(gistId);
    });

    return samplesMenu;
  }

  void _initMoreMenu() {
    final moreMenuButton = querySelector('#more-menu-button') as ButtonElement;
    final moreMenu = MDCMenu(querySelector('#more-menu'))
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(moreMenuButton)
      ..hoistMenuToBody();
    MDCButton(moreMenuButton, isIcon: true)
        .onClick
        .listen((_) => _toggleMenu(moreMenu));
    moreMenu.listen('MDCMenu:selected', (e) {
      final idx = (e as CustomEvent).detail['index'] as int?;
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

  Element _buildChannelsMenu(List<Channel> channels) {
    final element = querySelector('#channels-menu')!;
    element.children = [];

    final listElement = _mdcList();
    element.children.add(listElement);

    final currentChannel = queryParams.channel;

    for (final channel in channels) {
      final checkmark = SpanElement()
        ..id = ('${channel.name}-checkmark')
        ..classes.add('channel-menu-left')
        ..classes.add('mdc-list-item__graphic')
        ..children.add(
          LIElement()
            ..classes.addAll(['material-icons', 'mdc-select__icon'])
            ..tabIndex = -1
            ..attributes['role'] = 'button'
            ..text = 'check',
        );

      if (currentChannel != channel.name) {
        checkmark.classes.toggle('hide');
      }

      final menuElement = _mdcListItem(children: [
        DivElement()
          ..classes.add('channel-item-group')
          ..children = [
            checkmark,
            SpanElement()
              ..classes.add('channel-menu-right')
              ..children = [
                ParagraphElement()
                  ..classes.add('mdc-list-item__title')
                  ..text = '${channel.name} channel',
                ParagraphElement()
                  ..classes.add('mdc-list-item__details')
                  ..text =
                      'Use Flutter version ${channel.flutterVersion} and Dart '
                          'version ${channel.dartVersion}',
              ],
          ],
      ])
        ..classes.add('channel-item');

      // The dev channel is hidden unless it's selected via a query parameter.
      if (!channel.hidden || currentChannel == channel.name) {
        listElement.children.add(menuElement);
      }
    }

    return element;
  }

  Future<void> _initChannelsMenu() async {
    channels = await Future.wait([
      Channel.fromVersion('stable'),
      Channel.fromVersion('beta'),
      Channel.fromVersion('old'),
      Channel.fromVersion('dev', hidden: true),
    ]);

    final element = _buildChannelsMenu(channels);
    _configureChannelsMenu(element);

    // Set the initial channel from the current query parameter
    _handleChannelSwitched(queryParams.channel);
  }

  void _configureChannelsMenu(Element menuElement) {
    _channelsMenu?.unlisten('MDCMenu:selected', _handleChannelsMenuSelected);
    _channelsMenu = MDCMenu(menuElement)
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(_channelsDropdownButton)
      ..hoistMenuToBody();

    _channelsMenu?.listen('MDCMenu:selected', _handleChannelsMenuSelected);
  }

  void _handleChannelsMenuSelected(e) {
    final index = (e as CustomEvent).detail['index'] as int;
    final channel = Channel.urlMapping.keys.toList()[index];
    _handleChannelSwitched(channel);
  }

  UListElement _mdcList() => UListElement()
    ..classes.add('mdc-list')
    ..attributes.addAll({
      'aria-hidden': 'true',
      'aria-orientation': 'vertical',
      'tabindex': '-1'
    });

  LIElement _mdcListItem({List<Element> children = const []}) {
    final element = LIElement()
      ..classes.add('mdc-list-item')
      ..classes.add('channel-menu-list')
      ..attributes.addAll({'role': 'menuitem'});
    for (final child in children) {
      element.children.add(child);
    }
    return element;
  }

  void _initSplitters() {
    final editorPanel = querySelector('#editor-panel')!;
    final outputPanel = querySelector('#output-panel')!;

    flexSplit(
      [editorPanel, outputPanel],
      horizontal: true,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: const [100, 100],
    );

    listenForResize(editorPanel);
  }

  void _initRightSplitter() {
    if (_rightSplitterConfigured) {
      return;
    }

    final outputHost = querySelector('#right-output-panel')!;
    _rightSplitter = flexSplit(
      [outputHost, _rightDocPanel],
      horizontal: false,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: const [100, 100],
    );
    _rightSplitterConfigured = true;

    listenForResize(outputHost);
  }

  void _disposeRightSplitter() {
    if (!_rightSplitterConfigured) {
      // The right splitter might already be destroyed.
      return;
    }
    _rightSplitter.destroy();
    _rightSplitterConfigured = false;
  }

  void _initOutputPanelTabs() {
    if (_tabExpandController != null) {
      return;
    }

    _tabExpandController = TabExpandController(
      consoleButton: _editorConsoleTab,
      docsButton: _editorDocsTab,
      clearConsoleButton: _consoleClearLeftButton,
      closeButton: _closePanelButton,
      docsElement: _leftDocPanel,
      consoleElement: _leftConsoleElement,
      topSplit: _editorHost,
      bottomSplit: _editorPanelFooter.element,
      unreadCounter: _unreadConsoleCounter,
      editorUi: this,
    );
  }

  void _disposeOutputPanelTabs() {
    _tabExpandController?.dispose();
    _tabExpandController = null;
  }

  MaterialTabController _buildTabs() {
    final webLayoutTabController =
        MaterialTabController(MDCTabBar(_webTabBar.element));
    for (final name in ['dart', 'html', 'css']) {
      webLayoutTabController.registerTab(
          TabElement(querySelector('#$name-tab')!, name: name, onSelect: () {
        ga.sendEvent('edit', name);
        context.switchTo(name);
      }));
    }

    return webLayoutTabController;
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

  static Future<void> _initModules() async {
    final modules = ModuleManager();

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
      ..keyMap = window.localStorage['codemirror_keymap'] ?? 'default'
      ..showLineNumbers = true;

    initKeyBindings();

    context = PlaygroundContext(editor);
    deps[Context] = context;

    editorFactory.registerCompleter(
        'dart', DartCompleter(dartServices, context.dartDocument));

    context.onDartDirty.listen((_) => busyLight.on());
    context.onDartReconcile.listen((_) => performAnalysis());

    final Property htmlFile =
        GistFileProperty(_editableGist.getGistFile('index.html'));
    final Property htmlDoc =
        EditorDocumentProperty(context.htmlDocument, 'html');
    bind(htmlDoc, htmlFile);
    bind(htmlFile, htmlDoc);

    final Property cssFile =
        GistFileProperty(_editableGist.getGistFile('styles.css'));
    final Property cssDoc = EditorDocumentProperty(context.cssDocument, 'css');
    bind(cssDoc, cssFile);
    bind(cssFile, cssDoc);

    final Property dartFile =
        GistFileProperty(_editableGist.getGistFile('main.dart'));
    final Property dartDoc =
        EditorDocumentProperty(context.dartDocument, 'dart');
    bind(dartDoc, dartFile);
    bind(dartFile, dartDoc);

    // Listen for changes that would effect the documentation panel.
    editor.onMouseDown.listen((e) {
      // Delay to give codemirror time to process the mouse event.
      Timer.run(() {
        if (!context.cursorPositionIsWhitespace()) {
          _docHandler.generateDoc([_rightDocContentElement, _leftDocPanel]);
        }
      });
    });

    _docHandler = DocHandler(editor, context);

    updateVersions();

    analysisResultsController = AnalysisResultsController(
      DElement(querySelector('#issues')!),
      DElement(querySelector('#issues-message')!),
      DElement(querySelector('#issues-toggle')!),
      snackbar,
    )..onItemClicked.listen((item) {
        _jumpTo(item.line, item.charStart, item.charLength, focus: true);
      });

    _finishedInit();
  }

  @override
  void initKeyBindings() {
    keys.bind(['ctrl-s'], _handleSave, 'Save', hidden: true);
    keys.bind(['f1'], () {
      ga.sendEvent('main', 'help');
      _docHandler.generateDoc([_rightDocContentElement, _leftDocPanel]);
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
        _docHandler.generateDoc([_rightDocContentElement, _leftDocPanel]);
      }
      _handleAutoCompletion(e);
    });

    super.initKeyBindings();
  }

  void _finishedInit() {
    // Clear the splash.
    final splash = DSplash(querySelector('div.splash')!);
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
    final loadResult = _loadGist();

    // If no gist was loaded, use a new Dart gist.
    if (loadResult == LoadGistResult.none) {
      _editableGist.setBackingGist(_createGist(layout));

      // Store the gist so that the same sample is loaded when the page is
      // refreshed.
      _gistStorage.setStoredGist(_editableGist.createGist());
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
      final blankGist = Gist();
      _editableGist.setBackingGist(blankGist);

      final storedGist = _gistStorage.getStoredGist()!;

      // Set the editable gist's backing gist so that the route handler can
      // detect the project type.
      _editableGist.setBackingGist(storedGist);

      _editableGist.description = storedGist.description;
      for (final file in storedGist.files) {
        _editableGist.getGistFile(file.name).content = file.content;
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
    } else if (_editableGist.backingGist.id == gistId) {
      return;
    }

    _showGist(gistId);
    queryParams.gistId = gistId;
  }

  void _showGist(String gistId) {
    if (_gistIdInProgress == gistId) {
      return;
    }
    // Don't auto-run if we're re-loading some unsaved edits; the gist might
    // have halting issues (#384).
    var loadedFromSaved = false;

    // When sharing, we have to pipe the returned (created) gist through the
    // routing library to update the url properly.
    final overrideNextRouteGist = _overrideNextRouteGist;
    if (overrideNextRouteGist != null && overrideNextRouteGist.id == gistId) {
      _editableGist.setBackingGist(overrideNextRouteGist);
      _overrideNextRouteGist = null;
      return;
    }

    _overrideNextRouteGist = null;

    _gistIdInProgress = gistId;
    gistLoader.loadGist(gistId).then((Gist gist) {
      _editableGist.setBackingGist(gist);

      if (_gistStorage.hasStoredGist && _gistStorage.storedId == gistId) {
        loadedFromSaved = true;

        final storedGist = _gistStorage.getStoredGist()!;
        _editableGist.description = storedGist.description;
        for (final file in storedGist.files) {
          _editableGist.getGistFile(file.name).content = file.content;
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
      final message = 'Error loading gist $gistId.';
      showSnackbar(message);
      _logger.severe('$message: $e');
    }).whenComplete(() {
      _gistIdInProgress = null;
    });
  }

  @override
  Future<bool> handleRun() async {
    final success = await super.handleRun();
    if (success) {
      _webOutputLabel.setAttr('hidden');
    }
    return success;
  }

  Future<void> _format() {
    final originalSource = context.dartSource;
    final input = SourceRequest()..source = originalSource;
    _formatButton.disabled = true;

    final request = dartServices.format(input).timeout(serviceCallTimeout);
    return request.then((FormatResponse result) {
      busyLight.reset();
      _formatButton.disabled = false;

      if (result.newString.isEmpty) {
        _logger.fine('Format returned null/empty result');
        return;
      }

      if (originalSource != result.newString) {
        context.dartSource = result.newString;
        showSnackbar('Format successful.');
      } else {
        showSnackbar('No formatting changes.');
      }
    }).catchError((e) {
      busyLight.reset();
      _formatButton.disabled = false;
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
    _unreadConsoleCounter.clear();
  }

  @override
  void showOutput(String message, {bool error = false}) {
    _leftConsole.showOutput(message, error: error);
    _rightConsole.showOutput(message, error: error);

    // If there are no tabs visible or the console is not being displayed,
    // increment the counter.
    if (_tabExpandController == null ||
        _tabExpandController!.state != TabState.console) {
      _unreadConsoleCounter.increment();
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
        _editorPanelFooter.setAttr('hidden');
        _disposeOutputPanelTabs();
        _rightDocPanel.attributes.remove('hidden');
        _rightConsoleElement.attributes.remove('hidden');
        _webTabBar.setAttr('hidden');
        _webLayoutTabController.selectTab('dart');
        _initRightSplitter();
        _editorPanelHeader.setAttr('hidden');
        _webOutputLabel.setAttr('hidden');
        _searchController.searchDialogDiv
            .toggleClass('search-playground-dart', true);
        _searchController.searchDialogDiv
            .toggleClass('search-playground-html', false);
        _searchController.searchDialogDiv
            .toggleClass('search-playground-flutter', false);
        break;
      case Layout.html:
        _disposeRightSplitter();
        _frame.hidden = false;
        _editorPanelFooter.clearAttr('hidden');
        _initOutputPanelTabs();
        _rightDocPanel.setAttribute('hidden', '');
        _rightConsoleElement.setAttribute('hidden', '');
        _webTabBar.toggleAttr('hidden', false);
        _webLayoutTabController.selectTab('dart');
        _editorPanelHeader.clearAttr('hidden');
        _webOutputLabel.setAttr('hidden');
        _searchController.searchDialogDiv
            .toggleClass('search-playground-dart', false);
        _searchController.searchDialogDiv
            .toggleClass('search-playground-html', true);
        _searchController.searchDialogDiv
            .toggleClass('search-playground-flutter', false);
        break;
      case Layout.flutter:
        _disposeRightSplitter();
        _frame.hidden = false;
        _editorPanelFooter.clearAttr('hidden');
        _initOutputPanelTabs();
        _rightDocPanel.setAttribute('hidden', '');
        _rightConsoleElement.setAttribute('hidden', '');
        _webTabBar.setAttr('hidden');
        _webLayoutTabController.selectTab('dart');
        _editorPanelHeader.setAttr('hidden');
        _webOutputLabel.clearAttr('hidden');
        _searchController.searchDialogDiv
            .toggleClass('search-playground-dart', false);
        _searchController.searchDialogDiv
            .toggleClass('search-playground-html', false);
        _searchController.searchDialogDiv
            .toggleClass('search-playground-flutter', true);
        break;
    }
  }

  /// Carries out various tasks to update the channel:
  ///
  /// * switches the API root URL
  /// * updates the URL query parameters
  /// * re-analyzes the source
  // TODO(srawlins): Re-initialize the samples menu.
  void _handleChannelSwitched(String channel) {
    if (!Channel.urlMapping.keys.contains(channel)) {
      return;
    }
    queryParams.channel = channel;
    final buttonText =
        _channelsDropdownButton.querySelector('.mdc-button__label')!;
    buttonText.text = '$channel channel';
    dartServices.rootUrl = Channel.urlMapping[channel]!;
    updateVersions();
    performAnalysis();

    // Re-create the channels menu to show the correct checkmark
    for (final channelName in Channel.urlMapping.keys) {
      final checkmark = document.querySelector('#$channelName-checkmark');
      if (checkmark == null) {
        continue;
      }
      if (channel == channelName) {
        checkmark.classes.remove('hide');
      } else {
        checkmark.classes.add('hide');
      }
    }
  }

  // GistContainer interface
  @override
  MutableGist get mutableGist => _editableGist;

  @override
  void overrideNextRoute(Gist gist) {
    _overrideNextRouteGist = gist;
  }

  Future<void> _showCreateGistDialog() async {
    final layout = await _newPadDialog.show();
    if (layout == null) return;
    await createGistForLayout(layout);
  }

  Future<void> _showResetDialog() async {
    final result = await dialog.showOkCancel(
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
    _editableGist.reset();
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




void _initGitHubMenu() {
    final githubMenuButton = querySelector('#github-menu-button') as ButtonElement;
    final githubMenu = MDCMenu(querySelector('#github-menu'))
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(githubMenuButton)
      ..hoistMenuToBody();
    MDCButton(githubMenuButton, isIcon: true)
        .onClick
        .listen((_) => _toggleMenu(githubMenu));
    githubMenu.listen('MDCMenu:selected', (e) {
      final idx = (e as CustomEvent).detail['index'] as int?;
      switch (idx) {
        case 0:
          _attempToAquireGitHubToken();
          break;
        case 1: // create public
          _saveGist();
          break;
        case 2: // create private
          _saveGist(public:false);
          break;        
        case 3:
          _forkGist();
          break;
        case 4: //update
          _updateGist();
          break;
        case 5:
          //star gist;
          break;
        case 6:
          //add comment;
          break;
        case 7:
          //logout;
          _githubController.logoutUnauthenticate();
          break;
      }
    });
  }

  static const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random _rnd = Random();

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  final String googleCloudRunUrl='https://githubauth-brsyns7rna-uw.a.run.app';

  void _attempToAquireGitHubToken() {
    var state=getRandomString(24);

    Uri ourUri = Uri.dataFromString(window.location.href);
    if(ourUri.host.contains('localhost')) {
      window.location.href = 'https://localhost:8080/initiate/$state';
    } else {
      window.location.href = '$googleCloudRunUrl/initiate/$state';
    }
  }

  void _saveGist({bool public=true}) {
    final String token = _githubController.githubOAuthAccessToken;
    if(true || token.isNotEmpty) {

      gistLoader.saveGist(mutableGist.createGist(),public,token).then((String createdGistId) {
          window.console.log('Got created Gist ID =$createdGistId');
          showOutput('Got created Gist ID =$createdGistId');
          //queryParams.gistId = createdGistId;
          _reloadPageWithNewGistId(createdGistId);
      });
    } else {
      showSnackbar('Must be authenticated with GitHub in order to save gist');
    }
  }

  void _updateGist() {
    final String token = _githubController.githubOAuthAccessToken;
    if(true || token.isNotEmpty) {
      gistLoader.updateGist(mutableGist.createGist(),token).then((String updatedGistId) {
          window.console.log('Got Updated Gist ID =$updatedGistId');
          showOutput('Got Updated Gist ID =$updatedGistId');

          showSnackbar('Gist successfully updated');
          //queryParams.gistId = forkedGistId;
          //_reloadPageWithNewGistId(updatedGistId);
      });
    } else {
      showSnackbar('Must be authenticated with GitHub in order to fork gist');
    }
  }

  void _forkGist() {
    final String token = _githubController.githubOAuthAccessToken;
    if(true || token.isNotEmpty) {
      gistLoader.forkGist(mutableGist.createGist(),token).then((String forkedGistId) {
          window.console.log('Got Forked Gist ID =$forkedGistId');
          showOutput('Got forked Gist ID =$forkedGistId');

          showSnackbar('Gist successfully forked');  // This wont have time to show KLUDGE

          //queryParams.gistId = forkedGistId;
          _reloadPageWithNewGistId(forkedGistId);
      });
    } else {
      showSnackbar('Must be authenticated with GitHub in order to fork gist');
    }
  }

  _reloadPageWithNewGistId(String gistId) {
    var url = Uri.parse(window.location.toString());
    final params = Map<String, String?>.from(url.queryParameters);
    params['id'] = gistId;
    url = url.replace(queryParameters: params);
    window.location.href = url.toString();
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

    final completer = Completer<Layout?>();
    final dartSub = _dartButton.root.onClick.listen((_) {
      _flutterButton.root.classes.remove('selected');
      _dartButton.root.classes.add('selected');
      _createButton.toggleAttr('disabled', false);
      _htmlSwitchContainer.toggleClass('hide', false);
      _htmlSwitch.disabled = false;
    });

    final flutterSub = _flutterButton.root.onClick.listen((_) {
      _dartButton.root.classes.remove('selected');
      _flutterButton.root.classes.add('selected');
      _createButton.toggleAttr('disabled', false);
      _htmlSwitchContainer.toggleClass('hide', true);
    });

    final cancelSub = _cancelButton.onClick.listen((_) {
      completer.complete(null);
    });

    final createSub = _createButton.onClick.listen((_) {
      completer.complete(selectedLayout);
    });

    _mdcDialog.open();

    void handleClosing(Event _) {
      _flutterButton.root.classes.remove('selected');
      _dartButton.root.classes.remove('selected');
      _htmlSwitchContainer.toggleClass('hide', true);
      dartSub.cancel();
      flutterSub.cancel();
      cancelSub.cancel();
      createSub.cancel();
      _mdcDialog.unlisten('MDCDialog:closing', handleClosing);
    }

    _mdcDialog.listen('MDCDialog:closing', handleClosing);

    return completer.future.then((v) {
      _mdcDialog.close();
      return v;
    });
  }
}

class BuiltInSamplesList {
  static List<Sample> builtinSamples = [];

  static void addSample(final Sample sample) {
    builtinSamples.add(sample);
  }

  static void addSamples(final List<Sample> samples) {
    for(final sample in samples) {
      builtinSamples.add(sample);
    }
  }

  static bool isGistIDFromBuiltinSamples( final String gistId ) {
    for(final sample in builtinSamples) {
      if(gistId==sample.gistId) {
        return true;
      }
    }
    return false;
  }
}

class Sample {
  final String gistId;
  final String name;
  final Layout layout;

  const Sample(this.gistId, this.name, this.layout);
}


/* 
KLUDGE

          (_) {
    gistLoader.fuckSaveGist(mutableGist.backingGist).then((String createdGistId) {
        window.console.log('Got created Gist ID =$createdGistId');
        showOutput('Got created Gist ID =$createdGistId');
        queryParams.gistId = createdGistId;
    });



created a gist 0b3d5d3024883c290c05c7f6290736d0


created no auth gist  c2a93a3b0d76ce1ceb066a9bf822c8b0


    */

/*
    GET https://api.github.com/user
For example, in curl you can set the Authorization header like this:

curl -H "Authorization: token OAUTH-TOKEN" https://api.github.com/user

*/

class GitHubLoginController {
  static const String _githubApiUrl = 'https://api.github.com';
  final Uri launchUri;
  late final http.Client _client;

  GitHubLoginController( this.launchUri, { http.Client? client } ) {
    // check for parameters in rui
    _client = client ?? http.Client();
    Map<String,String> params = launchUri.queryParameters;


    window.console.log('GitHubLoginController() Launch URI  ${launchUri.toString()}');

    params.forEach((key,value) {
      print('  param $key = "$value"');
    });

    if(params['gh']!=null) {
      // provided a gh token
      githubOAuthAccessToken = params['gh']!;
      window.console.log('Calling getUserInfo()');
      getUserInfo();
    } else {
      // Do we have a access token
      if(githubOAuthAccessToken!='') {
        String avUrl = avatarUrl;
        avatarUrl = avUrl; // force loading image/KLUDGE
      }
    }
  }


  void logoutUnauthenticate() {
    githubOAuthAccessToken = '';
    avatarUrl = '';
    userLogin = '';
  }


  /*
     example of PUBLIC returned data

     
  "login": "octocat",
  "id": 1,
  "node_id": "MDQ6VXNlcjE=",
  "avatar_url": "https://github.com/images/error/octocat_happy.gif",
  "gravatar_id": "",
  "url": "https://api.github.com/users/octocat",
  "html_url": "https://github.com/octocat",
  "followers_url": "https://api.github.com/users/octocat/followers",
  "following_url": "https://api.github.com/users/octocat/following{/other_user}",
  "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}",
  "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}",
  "subscriptions_url": "https://api.github.com/users/octocat/subscriptions",
  "organizations_url": "https://api.github.com/users/octocat/orgs",
  "repos_url": "https://api.github.com/users/octocat/repos",
  "events_url": "https://api.github.com/users/octocat/events{/privacy}",
  "received_events_url": "https://api.github.com/users/octocat/received_events",
  "type": "User",
  "site_admin": false,
  "name": "monalisa octocat",
  "company": "GitHub",
  "blog": "https://github.com/blog",
  "location": "San Francisco",
  "email": "octocat@github.com",
  "hireable": false,
  "bio": "There once was...",
  "twitter_username": "monatheoctocat",
  "public_repos": 2,
  "public_gists": 1,
  "followers": 20,
  "following": 0,
  "created_at": "2008-01-14T04:33:35Z",
  "updated_at": "2008-01-14T04:33:35Z"
}

  Example of scope USER returned data
  {
  "login": "octocat",
  "id": 1,
  "node_id": "MDQ6VXNlcjE=",
  "avatar_url": "https://github.com/images/error/octocat_happy.gif",
  "gravatar_id": "",
  "url": "https://api.github.com/users/octocat",
  "html_url": "https://github.com/octocat",
  "followers_url": "https://api.github.com/users/octocat/followers",
  "following_url": "https://api.github.com/users/octocat/following{/other_user}",
  "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}",
  "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}",
  "subscriptions_url": "https://api.github.com/users/octocat/subscriptions",
  "organizations_url": "https://api.github.com/users/octocat/orgs",
  "repos_url": "https://api.github.com/users/octocat/repos",
  "events_url": "https://api.github.com/users/octocat/events{/privacy}",
  "received_events_url": "https://api.github.com/users/octocat/received_events",
  "type": "User",
  "site_admin": false,
  "name": "monalisa octocat",
  "company": "GitHub",
  "blog": "https://github.com/blog",
  "location": "San Francisco",
  "email": "octocat@github.com",
  "hireable": false,
  "bio": "There once was...",
  "twitter_username": "monatheoctocat",
  "public_repos": 2,
  "public_gists": 1,
  "followers": 20,
  "following": 0,
  "created_at": "2008-01-14T04:33:35Z",
  "updated_at": "2008-01-14T04:33:35Z",
  "private_gists": 81,
  "total_private_repos": 100,
  "owned_private_repos": 100,
  "disk_usage": 10000,
  "collaborators": 8,
  "two_factor_authentication": true,
  "plan": {
    "name": "Medium",
    "space": 400,
    "private_repos": 20,
    "collaborators": 0
  }
}

MY Public data:
user data {login: timmaffett, 
id: 3639881, 
node_id: MDQ6VXNlcjM2Mzk4ODE=, 
avatar_url: https://avatars.githubusercontent.com/u/3639881?v=4,
gravatar_id: , 
url: https://api.github.com/users/timmaffett, 
html_url: https://github.com/timmaffett, 
followers_url: https://api.github.com/users/timmaffett/followers, 
following_url: https://api.github.com/users/timmaffett/following{/other_user},
 gists_url: https://api.github.com/users/timmaffett/gists{/gist_id}, 
 starred_url: https://api.github.com/users/timmaffett/starred{/owner}{/repo}, 
 subscriptions_url: https://api.github.com/users/timmaffett/subscriptions, 
 organizations_url: https://api.github.com/users/timmaffett/orgs, 
 repos_url: https://api.github.com/users/timmaffett/repos, 
 events_url: https://api.github.com/users/timmaffett/events{/privacy}, 
 received_events_url: https://api.github.com/users/timmaffett/received_events,
  type: User, 
  site_admin: false, 
  name: Tim Maffett, 
  company: null, 
  blog: , 
  location: null, 
  email: timmaffett@gmail.com, 
  hireable: true,
   bio: null, 
   twitter_username: null,
    public_repos: 47, 
    public_gists: 2, 
    followers: 2, 
    following: 1,
     created_at: 2013-02-19T18:49:46Z, 
     updated_at: 2022-03-24T19:26:44Z}


*/
  void getUserInfo() async {
    final String accessToken = githubOAuthAccessToken;

    window.console.log('getUserInfo  accessToken=$accessToken');

    if(accessToken.isEmpty) return;

    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    final response = await _client.get(Uri.parse('$_githubApiUrl/user'),
                        headers:{ 'accept':'application/vnd.github.v3+json',
                                  'Authorization': 'token $accessToken'});

    window.console.log('reponsestatusCode=${response.statusCode}');

    if (response.statusCode == 404) {
      throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
    } else if (response.statusCode == 403) {
      throw const GistLoaderException(GistLoaderFailureType.rateLimitExceeded);
    } else if (response.statusCode != 200) {
      throw const GistLoaderException(GistLoaderFailureType.unknown);
    } else {
      // statusCode 200 
      final user = json.decode(response.body) as Map<String, dynamic>;
      if(user!=null) {
        window.console.log('user data ${user.toString()}');
        window.console.log('avatarURL= ${user['avatar_url']}');

        if(user.containsKey('avatar_url')) {
          avatarUrl = user['avatar_url'] as String;
        }
        if(user.containsKey('login')) {
          userLogin = user['login'] as String;
        }
      }
    }

  }

  set githubOAuthAccessToken(String newtoken) {
    window.console.log('Setting access token to $newtoken');
    if( window.localStorage['github_oauth_token'] != newtoken) {
      if(newtoken.isNotEmpty) {
        window.console.log('putting into local storage');
        window.localStorage['github_oauth_token'] = newtoken;
        // get the user info for this token
        window.console.log('calling getUserInfo');
        getUserInfo();
      } else {
        window.localStorage.remove('github_oauth_token');
      }
    }
  }

  String get githubOAuthAccessToken => window.localStorage['github_oauth_token'] ?? '';

  set avatarUrl(String url) {
    final ImageElement avatarImg = querySelector('#github-avatar') as ImageElement;
    window.console.log('setting avatar url to $url');
    if(url.isNotEmpty) {
      window.localStorage['github_avatar_url'] = url;

      window.console.log('Avatar url = $url');
      avatarImg.src=url;
    } else {
      window.localStorage.remove('github_avatar_url');
      avatarImg.removeAttribute('src');
    }
  }

  String get avatarUrl => window.localStorage['github_avatar_url'] ?? '';

  set userLogin(String login) {
    final LIElement loggedInAsLi = querySelector('#logged_in_as') as LIElement;
    final SpanElement loggedInAsText = querySelector('#logged_in_as_text') as SpanElement;
    window.console.log('setting loginl to $login');
    if(login.isNotEmpty) {
      window.localStorage['github_user_login'] = login;

      window.console.log('login = $login');
      loggedInAsText.innerText = 'Logged in as $login';
      loggedInAsLi.removeAttribute('hidden');
    } else {
      window.localStorage.remove('github_user_login');
      loggedInAsLi.setAttribute('hidden',true);
    }
  }

  String get userLogin => window.localStorage['github_user_login'] ?? '';
}


/*

example searches on
https://gist.github.com/search?q=language%3Adart+%22dartpad%22+stars%3A%3E%3D1&ref=searchresults


language:dart filename:main.dart "dartpad" stars:>=1


*/