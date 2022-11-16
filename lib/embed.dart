// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html' hide Document, Console;
import 'dart:math' as math;

import 'package:mdc_web/mdc_web.dart';
import 'package:split/split.dart';

import 'check_localstorage.dart';
import 'completion.dart';
import 'context.dart';
import 'core/dependencies.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'editing/editor_codemirror.dart';
import 'elements/analysis_results_controller.dart';
import 'elements/button.dart';
import 'elements/console.dart';
import 'elements/counter.dart';
import 'elements/dialog.dart';
import 'elements/elements.dart';
import 'elements/material_tab_controller.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'search_controller.dart';
import 'services/common.dart';
import 'services/dartservices.dart';
import 'services/execution_iframe.dart';
import 'sharing/editor_ui.dart';
import 'sharing/gists.dart';
import 'src/ga.dart';
import 'util/detect_flutter.dart';
import 'util/query_params.dart' show queryParams;

const int defaultSplitterWidth = 6;

Embed? get embed => _embed;

Embed? _embed;

void init(EmbedOptions options) {
  _embed = Embed(options);
}

// ignore: constant_identifier_names
enum EmbedMode { dart, flutter, html, inline, flutter_showcase }

class EmbedOptions {
  final EmbedMode mode;

  const EmbedOptions(this.mode);
}

/// An embeddable DartPad UI that provides the ability to test the user's code
/// snippet against a desired result.
class Embed extends EditorUi {
  final EmbedOptions options;

  var _executionButtonCount = 0;
  late final MDCButton reloadGistButton;
  late final MDCButton installButton;
  late final MDCButton formatButton;
  late final MDCButton showHintButton;
  late final MDCButton copyCodeButton;
  late final MDCButton openInDartPadButton;
  late final MDCButton menuButton;

  MDCButton? editorCodeInputTabButton;

  late final DElement navBarElement;
  late final EmbedTabController tabController;
  late final DElement solutionTab;
  late final MDCMenu menu;

  late final DElement showTestCodeCheckmark;
  late final DElement editableTestSolutionCheckmark;
  bool _editableTestSolution = false;
  bool _showTestCode = false;

  late final Counter unreadConsoleCounter;

  late final FlashBox testResultBox;
  late final FlashBox hintBox;

  final CodeMirrorFactory editorFactory = codeMirrorFactory;

  @override
  late final EmbedContext context;

  late Splitter splitter;

  late final Console consoleExpandController;
  DElement? webOutputLabel;
  late final DElement featureMessage;

  late final MDCLinearProgress linearProgress;
  Map<String, String> lastInjectedSourceCode = <String, String>{};

  bool _editorIsBusy = true;

  bool get editorIsBusy => _editorIsBusy;

  @override
  Document get currentDocument => context.dartDocument;

  /// Toggles the state of several UI components based on whether the editor is
  /// too busy to handle code changes, execute/reset requests, etc.
  set editorIsBusy(bool value) {
    _editorIsBusy = value;
    if (value) {
      linearProgress.root.classes.remove('hide');
    } else {
      linearProgress.root.classes.add('hide');
    }
    editor.readOnly = value;
    runButton.disabled = value;
    formatButton.disabled = value;
    reloadGistButton.disabled = value;
    showHintButton.disabled = value;
    copyCodeButton.disabled = value;
  }

  Embed(this.options) {
    _initHostListener();

    if (!checkLocalStorage()) {
      dialog.showOk(
          'Missing browser features',
          'DartPad requires localStorage to be enabled. '
              'For more information, visit '
              '<a href="https://dart.dev/tools/dartpad/troubleshoot" '
              'target="_parent">dart.dev/tools/dartpad/troubleshoot</a>.');
    }

    tabController =
        EmbedTabController(MDCTabBar(querySelector('.mdc-tab-bar')!), dialog);

    final tabNames = options.mode == EmbedMode.html
        ? const ['dart', 'html', 'css', 'solution', 'test']
        : const ['dart', 'solution', 'test'];

    for (final tabName in tabNames) {
      // The HTML ID and ga.sendEvent use 'editor' for the 'dart' tab.
      final String contextName = (tabName == 'dart') ? 'editor' : tabName;
      tabController.registerTab(
        TabElement(querySelector('#$contextName-tab')!, name: tabName,
            onSelect: () {
          ga.sendEvent('edit', contextName);
          context.switchTo(tabName);
          editor.resize();
          editor.focus();
        }),
      );
    }

    solutionTab = DElement(querySelector('#solution-tab')!);

    navBarElement = DElement(querySelector('#navbar')!);

    unreadConsoleCounter =
        Counter(querySelector('#unread-console-counter') as SpanElement);

    runButton = MDCButton(querySelector('#execute') as ButtonElement)
      ..onClick.listen((_) => handleRun());

    // Flutter showcase mode
    final editorCodeInputTabButtonElement =
        querySelector('#editor-panel-show-code-button');
    if (editorCodeInputTabButtonElement != null) {
      editorCodeInputTabButton =
          MDCButton(editorCodeInputTabButtonElement as ButtonElement)
            ..onClick.listen(
              (_) => _toggleCodeInput(),
            );
    }

    reloadGistButton = MDCButton(querySelector('#reload-gist') as ButtonElement)
      ..onClick.listen((_) {
        if (gistId!.isNotEmpty || sampleId.isNotEmpty || githubParamsPresent) {
          _loadAndShowGist();
        } else {
          _resetCode();
        }
      });

    copyCodeButton =
        MDCButton(querySelector('#copy-code') as ButtonElement, isIcon: true)
          ..onClick.listen((_) => _handleCopyCode());
    openInDartPadButton = MDCButton(
        querySelector('#open-in-dartpad') as ButtonElement,
        isIcon: true)
      ..onClick.listen((_) => _handleOpenInDartPad());

    showHintButton = MDCButton(querySelector('#show-hint') as ButtonElement)
      ..onClick.listen((_) {
        final hintElement = DivElement()..text = context.hint;
        final showSolutionButton = AnchorElement()
          ..style.cursor = 'pointer'
          ..text = 'Show solution';
        showSolutionButton.onClick.listen((_) {
          tabController.selectTab('solution', force: true);
        });
        hintBox.showElements([hintElement, showSolutionButton]);
        ga.sendEvent('view', 'hint');
      })
      ..element.hidden = true;

    tabController.setTabVisibility('test', false);
    showTestCodeCheckmark = DElement(querySelector('#show-test-checkmark')!);
    editableTestSolutionCheckmark =
        DElement(querySelector('#editable-test-solution-checkmark')!);

    menuButton =
        MDCButton(querySelector('#menu-button') as ButtonElement, isIcon: true)
          ..onClick.listen((_) {
            menu.open = !menu.open!;
          });
    menu = MDCMenu(querySelector('#main-menu'))
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(menuButton.element);
    menu.listen('MDCMenu:selected', (e) {
      final detail = (e as CustomEvent).detail as Map;
      final selectedIndex = detail['index'] as int?;
      switch (selectedIndex) {
        case 0:
          // Show test code
          _showTestCode = !_showTestCode;
          showTestCodeCheckmark.toggleClass('hide', !_showTestCode);
          tabController.setTabVisibility('test', _showTestCode);
          break;
        case 1:
          // Editable test/solution
          _editableTestSolution = !_editableTestSolution;
          editableTestSolutionCheckmark.toggleClass(
              'hide', !_editableTestSolution);

          context.testAndSolutionReadOnly = !_editableTestSolution;
          break;
      }
    });

    formatButton = MDCButton(querySelector('#format-code') as ButtonElement)
      ..onClick.listen(
        (_) => _format(),
      );
    installButton = MDCButton(querySelector('#install-button') as ButtonElement)
      ..onClick.listen(
        (_) => _showInstallPage(),
      );

    testResultBox = FlashBox(querySelector('#test-result-box') as DivElement);
    hintBox = FlashBox(querySelector('#hint-box') as DivElement);
    final editorTheme = isDarkMode ? 'darkpad' : 'dartpad';

    editor =
        editorFactory.createFromElement(querySelector('#user-code-editor')!)
          ..theme = editorTheme
          ..mode = 'dart'
          ..keyMap = window.localStorage['codemirror_keymap'] ?? 'default'
          ..showLineNumbers = true;

    if (!showInstallButton) {
      querySelector('#install-button')!.setAttribute('hidden', '');
    }

    executionService =
        ExecutionServiceIFrame(querySelector('#frame') as IFrameElement)
          ..frameSrc =
              isDarkMode ? 'scripts/frame_dark.html' : 'scripts/frame.html';

    executionService.onStderr.listen((err) {
      consoleExpandController.showOutput(err, error: true);
    });

    executionService.onStdout.listen((msg) {
      consoleExpandController.showOutput(msg);
    });

    executionService.testResults.listen((result) {
      if (result.messages.isEmpty) {
        result.messages
            .add(result.success ? 'All tests passed!' : 'Test failed.');
      }
      testResultBox.showStrings(
        result.messages,
        result.success ? FlashBoxStyle.success : FlashBoxStyle.warn,
      );
      if (result.success) {
        window.parent?.postMessage({
          'action': 'taskCompleted',
          'recommendedReward': 'dash-hat',
          'callbackId': 'string',
        }, '*');
      }
      ga.sendEvent(
          'execution', (result.success) ? 'test-success' : 'test-failure');
    });

    analysisResultsController = AnalysisResultsController(
      DElement(querySelector('#issues')!),
      DElement(querySelector('#issues-message')!),
      DElement(querySelector('#issues-toggle')!),
      snackbar,
    )..onItemClicked.listen((item) {
        if (item.sourceName == 'test.dart') {
          // must be test editor
          if (!_showTestCode) {
            _showTestCode = true;
            showTestCodeCheckmark.toggleClass('hide', !_showTestCode);
            tabController.setTabVisibility('test', _showTestCode);
          }
          tabController.selectTab('test');
          _jumpToTest(item.line, item.charStart, item.charLength, focus: true);
        } else {
          tabController.selectTab('dart');
          _jumpTo(item.line, item.charStart, item.charLength, focus: true);
        }
      });

    if (options.mode == EmbedMode.flutter ||
        options.mode == EmbedMode.html ||
        options.mode == EmbedMode.flutter_showcase) {
      final controller = _ConsoleExpandController(
          expandButton: querySelector('#console-output-header')!,
          footer: querySelector('#console-output-footer')!,
          expandIcon: querySelector('#console-expand-icon')!,
          unreadCounter: unreadConsoleCounter,
          consoleElement: querySelector('#console-output-container')!,
          editorUi: this,
          onSizeChanged: () {
            editor.resize();
          },
          darkMode: isDarkMode);
      consoleExpandController = controller;
      if (shouldOpenConsole) {
        controller.open();
      }
    } else {
      consoleExpandController = Console(
          DElement(querySelector('#console-output-container')!),
          darkMode: isDarkMode);
    }

    final MDCButton clearConsoleButton = MDCButton(
        querySelector('#console-clear-button') as ButtonElement,
        isIcon: true);
    clearConsoleButton.onClick.listen((event) {
      clearOutput();
      event.stopPropagation();
    });

    final webOutputLabelElement = querySelector('#web-output-label');
    if (webOutputLabelElement != null) {
      webOutputLabel = DElement(webOutputLabelElement);
    }

    featureMessage = DElement(querySelector('#feature-message')!);
    featureMessage.toggleAttr('hidden', true);

    linearProgress = MDCLinearProgress(querySelector('#progress-bar')!);
    linearProgress.determinate = false;

    _initBusyLights();

    _initModules().then((_) => _init()).then((_) => _emitReady());

    SearchController(editorFactory, editor, snackbar);
  }

  /// Initializes a listener for messages from the parent window. Allows this
  /// embedded iframe to display and run arbitrary Dart code.
  void _initHostListener() {
    window.addEventListener('message', (Object? event) {
      final data = (event as MessageEvent).data;
      if (data is! Map) {
        // Ignore unexpected messages
        return;
      }

      final type = data['type'];

      if (type == 'sourceCode') {
        lastInjectedSourceCode =
            Map<String, String>.from(data['sourceCode'] as Map);
        _resetCode();

        if (autoRunEnabled) {
          handleRun();
        }
      }
    });
  }

  /// Sends a ready message to the parent page
  void _emitReady() {
    window.parent!.postMessage(const {'sender': 'frame', 'type': 'ready'}, '*');
  }

  // Option for the GitHub gist ID that should be loaded into the editors.
  String? get gistId {
    final id = queryParams.gistId;
    return isLegalGistId(id) ? id : '';
  }

  // Option for Light / Dark theme (defaults to light)
  bool get isDarkMode {
    return queryParams.theme == 'dark';
  }

  // Option to run the snippet immediately (defaults to  false)
  bool get autoRunEnabled {
    return queryParams.autoRunEnabled;
  }

  bool get shouldOpenConsole {
    return queryParams.shouldOpenConsole;
  }

  // Whether or not to show the Install button. (defaults to true)
  bool get showInstallButton {
    if (queryParams.hasShowInstallButton) {
      return queryParams.showInstallButton;
    }

    // Default to true
    return true;
  }

  // ID of an API Doc sample that should be loaded into the editors.
  String get sampleId => queryParams.sampleId ?? '';

  // An optional channel indicating which version of the API Docs to use when
  // loading a sample. Defaults to the stable channel.
  FlutterSdkChannel get sampleChannel {
    final channelStr = queryParams.sampleChannel?.toLowerCase();

    if (channelStr == 'master') {
      return FlutterSdkChannel.master;
    } else if (channelStr == 'beta') {
      return FlutterSdkChannel.beta;
    } else {
      return FlutterSdkChannel.stable;
    }
  }

  // GitHub params for loading an exercise from a repo. The first three are
  // required to load something, while the fourth, gh_ref, is an optional branch
  // name or commit SHA.
  String get githubOwner => queryParams.githubOwner ?? '';

  String get githubRepo => queryParams.githubRepo ?? '';

  String get githubPath => queryParams.githubPath ?? '';

  String? get githubRef => queryParams.githubRef;

  bool get githubParamsPresent =>
      githubOwner.isNotEmpty && githubRepo.isNotEmpty && githubPath.isNotEmpty;

  Future<void> _initModules() async {
    final modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());

    await modules.start();
  }

  void _initBusyLights() {
    busyLight = DBusyLight(querySelector('#dartbusy')!);
  }

  void _init() {
    deps[GistLoader] = GistLoader.defaultFilters();
    deps[Analytics] = Analytics();

    final channel = queryParams.channel;
    if (Channel.urlMapping.keys.contains(channel)) {
      dartServices.rootUrl = Channel.urlMapping[channel]!;
    }

    context = EmbedContext(editor, !_editableTestSolution);

    editorFactory.registerCompleter(
        'dart', DartCompleter(dartServices, context.dartDocument));

    context.onDartDirty.listen((_) => busyLight.on());
    context.onDartReconcile.listen((_) => performAnalysis());

    initKeyBindings();

    var horizontal = true;
    final webOutput = querySelector('#web-output')!;
    List<Element> splitterElements;
    if (options.mode == EmbedMode.flutter || options.mode == EmbedMode.html) {
      final editorAndConsoleContainer =
          querySelector('#editor-and-console-container')!;
      splitterElements = [editorAndConsoleContainer, webOutput];
    } else if (options.mode == EmbedMode.inline) {
      final editorContainer = querySelector('#editor-container')!;
      final consoleView = querySelector('#console-view')!;
      consoleView.removeAttribute('hidden');
      splitterElements = [editorContainer, consoleView];
      horizontal = false;
    } else if (options.mode == EmbedMode.flutter_showcase) {
      // do not split elements in flutter_showcase mode
      splitterElements = <Element>[];
    } else {
      final editorContainer = querySelector('#editor-container')!;
      final consoleView = querySelector('#console-view')!;
      consoleView.removeAttribute('hidden');
      splitterElements = [editorContainer, consoleView];
    }

    // Flutter showcase mode does not show code input by default
    if (options.mode == EmbedMode.flutter_showcase) {
      querySelector('#editor-and-console-container')
          ?.setAttribute('hidden', '');
      _updateShowcase();
    } else {
      splitter = flexSplit(
        splitterElements,
        horizontal: horizontal,
        gutterSize: defaultSplitterWidth,
        // set initial sizes (in percentages)
        sizes: [initialSplitPercent, (100 - initialSplitPercent)],
        // set the minimum sizes (in pixels)
        minSize: [100, 100],
      );
      listenForResize(splitterElements[0]);
    }

    if (gistId!.isNotEmpty || sampleId.isNotEmpty || githubParamsPresent) {
      _loadAndShowGist(analyze: false);
    }

    if (gistId!.isEmpty) {
      openInDartPadButton.toggleAttr('hidden', true);
    }

    // set enabled/disabled state of various buttons
    editorIsBusy = false;
  }

  @override
  void initKeyBindings() {
    keys.bind(const ['ctrl-space', 'macctrl-space'], () {
      if (editor.hasFocus) {
        editor.showCompletions();
      }
    }, 'Completion');

    keys.bind(const ['alt-enter'], () {
      if (context.focusedEditor == 'dart') {
        editor.showCompletions(onlyShowFixes: true);
      }
    }, 'Quick fix');

    keys.bind(const ['shift-ctrl-f', 'shift-macctrl-f'], () {
      _format();
    }, 'Format');

    document.onKeyUp.listen(_handleAutoCompletion);
    super.initKeyBindings();
  }

  Future<void> _loadAndShowGist({bool analyze = true}) async {
    if (gistId!.isEmpty && sampleId.isEmpty && !githubParamsPresent) {
      print('Cannot load gist: neither id, sample_id, nor GitHub repo info is '
          'present.');
      return;
    }

    editorIsBusy = true;

    final loader = deps[GistLoader] as GistLoader?;

    try {
      Gist gist;

      if (gistId!.isNotEmpty) {
        gist = await loader!.loadGist(gistId);
      } else if (sampleId.isNotEmpty) {
        // Right now, there are only two hosted versions of the docs: master and
        // stable. Default to stable for dev and beta.
        final channel = (sampleChannel == FlutterSdkChannel.master)
            ? FlutterSdkChannel.master
            : FlutterSdkChannel.stable;
        gist = await loader!.loadGistFromAPIDocs(sampleId, channel);
      } else {
        gist = await loader!.loadGistFromRepo(
          owner: githubOwner,
          repo: githubRepo,
          path: githubPath,
          ref: githubRef,
        );
      }

      setContextSources(<String, String>{
        'main.dart': gist.getFile('main.dart')?.content ?? '',
        'index.html': gist.getFile('index.html')?.content ?? '',
        'styles.css': gist.getFile('styles.css')?.content ?? '',
        'solution.dart': gist.getFile('solution.dart')?.content ?? '',
        'test.dart': gist.getFile('test.dart')?.content ?? '',
        'hint.txt': gist.getFile('hint.txt')?.content ?? '',
      });

      if (analyze) {
        unawaited(performAnalysis());
      }

      if (autoRunEnabled) {
        unawaited(handleRun());
      }
    } on GistLoaderException catch (ex) {
      // No gist was loaded, so clear the editors.
      setContextSources(<String, String>{});

      if (ex.failureType == GistLoaderFailureType.contentNotFound) {
        await dialog.showOk(
            'Error loading gist',
            'No gist was found for the gist ID, sample ID, or repository '
                'information provided.');
      } else if (ex.failureType == GistLoaderFailureType.rateLimitExceeded) {
        await dialog.showOk(
            'Error loading files',
            'GitHub\'s rate limit for '
                'API requests has been exceeded. This is typically caused by '
                'repeatedly loading a single page that has many DartPad embeds or '
                'when many users are accessing DartPad (and therefore GitHub\'s '
                'API server) from a single, shared IP address. Quotas are '
                'typically renewed within an hour, so the best course of action is '
                'to try back later.');
      } else if (ex.failureType ==
          GistLoaderFailureType.invalidExerciseMetadata) {
        if (ex.message != null) {
          print(ex.message);
        }
        await dialog.showOk(
            'Error loading files',
            'DartPad could not load the requested exercise. Either one of the '
                'required files wasn\'t available, or the exercise metadata was '
                'invalid.');
      } else {
        await dialog.showOk('Error loading files',
            'An error occurred while the requested files.');
      }
    }
  }

  void _resetCode() {
    setContextSources(lastInjectedSourceCode);
    Timer.run(() => unawaited(performAnalysis()));
  }

  void _handleCopyCode() {
    final textElement = document.createElement('textarea') as TextAreaElement;
    textElement.value = _getActiveSourceCode();
    document.body!.append(textElement);
    textElement.select();
    document.execCommand('copy');
    textElement.remove();
  }

  void _handleOpenInDartPad() {
    window.open(window.location.href, 'DartPad_$gistId');
  }

  /// Returns the name of the current embed mode
  /// (html, flutter, inline, dart, flutter_showcase).
  String get _modeName {
    return options.mode.toString().split('.').last;
  }

  String _getActiveSourceCode() {
    final activeTabName = tabController.selectedTab.name;

    switch (activeTabName) {
      case 'dart':
        return context.dartSource;
      case 'css':
        return context.cssSource;
      case 'html':
        return context.htmlSource;
      case 'solution':
        return context.solution;
      case 'test':
        return context.testMethod;
      default:
        return context.dartSource;
    }
  }

  void setContextSources(Map<String, String> sources) {
    context.dartSource = sources['main.dart'] ?? '';
    context.solution = sources['solution.dart'] ?? '';
    context.testMethod = sources['test.dart'] ?? '';
    context.htmlSource = sources['index.html'] ?? '';
    context.cssSource = sources['styles.css'] ?? '';
    context.hint = sources['hint.txt'] ?? '';
    if (sources.containsKey('ga_id')) {
      _sendVirtualPageView(sources['ga_id']);
    }
    tabController.setTabVisibility(
        'test', context.testMethod.isNotEmpty && _showTestCode);
    menuButton.toggleAttr('hidden', false);
    showHintButton.element.hidden = context.hint.isEmpty;
    solutionTab.toggleAttr('hidden', context.solution.isEmpty);
    editorIsBusy = false;
  }

  @override
  String get fullDartSource => '${context.dartSource}\n${context.testMethod}\n'
      '${executionService.testResultDecoration}';

  @override
  Future<bool> handleRun() async {
    if (editorIsBusy) {
      return false;
    }

    if (context.dartSource.isEmpty) {
      unawaited(dialog.showOk(
          'No code to execute',
          'Try entering some Dart code into the "Dart" tab, then click this '
              'button again to run it.'));
      return false;
    }

    _executionButtonCount++;
    ga.sendEvent('execution', 'initiated', label: '$_executionButtonCount');

    editorIsBusy = true;
    testResultBox.hide();
    hintBox.hide();
    consoleExpandController.clear();

    final success = await super.handleRun();

    editorIsBusy = false;

    // The iframe will show Flutter output for the rest of the lifetime of the
    // app, so hide the label.
    webOutputLabel?.setAttr('hidden');

    return success;
  }

  void _toggleCodeInput() {
    final editorAndConsoleContainer =
        querySelector('#editor-and-console-container')!;
    final webOutput = querySelector('#web-output')!;

    final isEditorHidden = editorAndConsoleContainer.hidden;

    if (isEditorHidden) {
      // show code input, hide UI output
      editorCodeInputTabButton!.text = 'Hide code';
      editorAndConsoleContainer.removeAttribute('hidden');
      webOutput.setAttribute('hidden', '');
      _updateShowcase(isEditorVisible: true);

      // run format to force to display the code & show caret in the editor
      _format();
    } else {
      // hide code input, show UI output
      editorCodeInputTabButton!.text = 'Show code';
      editorAndConsoleContainer.setAttribute('hidden', '');
      webOutput.removeAttribute('hidden');
      _updateShowcase();
    }
  }

  void _updateShowcase({bool isEditorVisible = false}) {
    final webOutput = querySelector('#web-output')!;
    final editorAndConsoleContainer =
        querySelector('#editor-and-console-container')!;

    splitter = flexSplit(
      <Element>[isEditorVisible ? editorAndConsoleContainer : webOutput],
      horizontal: true,
      gutterSize: 0,
      sizes: [100],
      minSize: [100],
    );
  }

  void _sendVirtualPageView(String? id) {
    final url = Uri.parse(window.location.toString());
    final newParams = Map<String, String?>.from(url.queryParameters);
    newParams['ga_id'] = id;
    final pageName = url.replace(queryParameters: newParams);
    final path = '${pageName.path}?${pageName.query}';
    ga.sendPage(pageName: path);
  }

  @override
  void displayIssues(List<AnalysisIssue> issues) {
    testResultBox.hide();
    hintBox.hide();

    // Handle possiblity of issues in appended test code.
    analysisResultsController
        .display(detectIssuesInTestSourceAndModifyIssuesAccordingly(issues));
  }

  // We append test source code to the user's source code, because of
  // this we possibly have a special situation..
  // There could be warnings or errors in the *TEST* code that is being
  // appended to the user's dart source.
  // This can result in issues with line numbers that are
  // outside the user's dart source.  This would confusing to the users.
  // We are going to do one of two things:
  // - If the test source is currently HIDDEN and the issue kind is
  // not and `error` (it is `info` or `warning`) then we will REMOVE
  // the issue from the list so as to "hide" it.
  // - If the test source is showing, *or* if the issue is an `error`, we are
  // going to adjust the line number so it reflects where it is in the
  // test source editor, and we will set the `sourceName` for the issue to
  // `test.dart`.
  List<AnalysisIssue> detectIssuesInTestSourceAndModifyIssuesAccordingly(
      List<AnalysisIssue> issues) {
    final int dartSourceLineCount = context.dartSourceLineCount;
    final int dartSourceCharCount = context.dartSource.length;
    issues = issues.map((issue) {
      if (issue.line > dartSourceLineCount) {
        // This is in the test source, do we adjust or hide it ?
        // (We never hide errors).
        if (issue.kind != 'error' && !_showTestCode) {
          // We want to remove the message later so flag it.
          return AnalysisIssue(line: -99);
        } else {
          // Adjust the line number, charStart and set sourceName
          // to indicate this issue is in the test code.
          return AnalysisIssue(
              kind: issue.kind,
              line: (issue.line - dartSourceLineCount - 1),
              message: issue.message,
              sourceName: 'test.dart',
              hasFixes: issue.hasFixes,
              charStart: (issue.charStart - dartSourceCharCount),
              charLength: issue.charLength,
              url: issue.url,
              diagnosticMessages: issue.diagnosticMessages,
              correction: issue.correction);
        }
      }
      return issue;
    }).toList();
    issues.removeWhere((issue) => issue.line == -99);
    return issues;
  }

  void _showInstallPage() {
    if (_modeName == 'dart' || _modeName == 'html') {
      ga.sendEvent('main', 'install-dart');
      window.open('https://dart.dev/get-dart', '_blank');
    } else {
      ga.sendEvent('main', 'install-flutter');
      window.open('https://flutter.dev/get-started/install', '_blank');
    }
  }

  Future<void> _format() async {
    final originalSource = context.dartSource;
    final input = SourceRequest()..source = originalSource;

    try {
      formatButton.disabled = true;
      final result =
          await dartServices.format(input).timeout(serviceCallTimeout);

      busyLight.reset();
      formatButton.disabled = false;

      // Check that the user hasn't edited the source since the format request.
      if (originalSource == context.dartSource) {
        // And, check that the format request did modify the source code.
        if (originalSource != result.newString) {
          context.dartSource = result.newString;
          unawaited(performAnalysis());
        }
      }
    } catch (e) {
      busyLight.reset();
      formatButton.disabled = false;
      print(e);
    }
  }

  void _handleAutoCompletion(KeyboardEvent e) {
    if (context.focusedEditor == 'dart' &&
        editor.hasFocus &&
        e.keyCode == KeyCode.PERIOD) {
      editor.showCompletions(autoInvoked: true);
    }
  }

  int get initialSplitPercent {
    const defaultSplitPercentage = 70;

    var s = queryParams.initialSplit ?? defaultSplitPercentage;

    // keep the split within the range [5, 95]
    s = math.min(s, 95);
    s = math.max(s, 5);
    return s;
  }

  void _jumpTo(int line, int charStart, int charLength, {bool focus = false}) {
    final doc = context.dartDocument;

    doc.select(
        doc.posFromIndex(charStart), doc.posFromIndex(charStart + charLength));

    if (focus) context.focus();
  }

  void _jumpToTest(int line, int charStart, int charLength,
      {bool focus = false}) {
    final doc = context.testDocument;

    doc.select(
        doc.posFromIndex(charStart), doc.posFromIndex(charStart + charLength));

    if (focus) context.focus();
  }

  @override
  void clearOutput() {
    consoleExpandController.clear();
  }

  @override
  bool get shouldAddFirebaseJs => hasFirebaseContent(fullDartSource);

  @override
  bool get shouldCompileDDC =>
      options.mode == EmbedMode.flutter ||
      options.mode == EmbedMode.flutter_showcase;

  @override
  void showOutput(String message, {bool error = false}) {
    consoleExpandController.showOutput(message, error: error);
  }
}

// material-components-web uses specific classes for its navigation styling,
// rather than an attribute. This class extends the tab controller code to also
// toggle that class.
class EmbedTabController extends MaterialTabController {
  final Dialog _dialog;
  bool _userHasSeenSolution = false;

  EmbedTabController(super.tabBar, this._dialog);

  @override
  void registerTab(TabElement tab) {
    tabs.add(tab);

    try {
      tab.onClick
          .listen((_) => selectTab(tab.name, force: _userHasSeenSolution));
    } catch (e, st) {
      print('Error from registerTab: $e\n$st');
    }
  }

  /// This method will throw if the tabName is not the name of a current tab.
  @override
  Future<void> selectTab(String tabName, {bool force = false}) async {
    // Show a confirmation dialog if the solution tab is tapped
    if (tabName == 'solution' && !force) {
      final result = await _dialog.showYesNo(
        'Show solution?',
        'If you just want a hint, click <span style="font-weight:bold">Cancel'
            '</span> and then <span style="font-weight:bold">Hint</span>.',
        yesText: 'Show solution',
        noText: 'Cancel',
      );
      // Go back to the editor tab
      if (result == DialogResult.no || result == DialogResult.cancel) {
        tabName = 'dart';
      }
    }

    if (tabName == 'solution') {
      ga.sendEvent('view', 'solution');
      _userHasSeenSolution = true;
    }

    await super.selectTab(tabName);
  }
}

/// It's a real word, I swear.
class DisableableButton {
  DisableableButton(ButtonElement anchorElement, VoidCallback onClick) {
    _element = DElement(anchorElement);
    _element.onClick.listen((e) {
      if (!_disabled) {
        onClick();
      }
    });
  }

  static const _disabledClassName = 'disabled';

  late DElement _element;

  bool _disabled = false;

  bool get disabled => _disabled;

  set disabled(bool value) {
    _disabled = value;
    _element.toggleClass(_disabledClassName, value);
  }

  set hidden(bool value) {
    _element.toggleAttr('hidden', value);
  }
}

enum FlashBoxStyle {
  warn,
  error,
  success,
}

class FlashBox {
  /// This constructor will throw if [div] does not have a child with the
  /// flash-close class and a child with the message-container class.
  FlashBox(DivElement div) {
    _element = DElement(div);
    _messageContainer = DElement(div.querySelector('.message-container')!);

    final closeLink = DElement(div.querySelector('.close-flash-container')!);
    closeLink.onClick.listen((event) {
      hide();
    });
  }

  static const _classNamesForStyles = <FlashBoxStyle, String>{
    FlashBoxStyle.warn: 'flash-warn',
    FlashBoxStyle.error: 'flash-error',
    FlashBoxStyle.success: 'flash-success',
  };

  late final DElement _element;

  late final DElement _messageContainer;

  void showStrings(List<String> messages, [FlashBoxStyle? style]) {
    showElements(messages.map((m) => DivElement()..text = m).toList(), style);
  }

  void showElements(List<Element> elements, [FlashBoxStyle? style]) {
    _element.clearAttr('hidden');
    _element.element.classes
        .removeWhere((s) => _classNamesForStyles.values.contains(s));

    if (style != null) {
      _element.toggleClass(_classNamesForStyles[style], true);
    }

    _messageContainer.clearChildren();

    for (final element in elements) {
      _messageContainer.add(element);
    }
  }

  void hide() {
    _element.setAttr('hidden');
  }

  void show() {
    _element.clearAttr('hidden');
  }
}

class _ConsoleExpandController extends Console {
  final DElement expandButton;
  final DElement footer;
  final DElement expandIcon;
  final Counter unreadCounter;
  final void Function() onSizeChanged;
  final EditorUi editorUi;
  late Splitter _splitter;
  var _expanded = false;

  _ConsoleExpandController({
    required Element expandButton,
    required Element footer,
    required Element expandIcon,
    required Element consoleElement,
    required this.unreadCounter,
    required this.editorUi,
    required this.onSizeChanged,
    required bool darkMode,
  })  : expandButton = DElement(expandButton),
        footer = DElement(footer),
        expandIcon = DElement(expandIcon),
        super(DElement(consoleElement),
            errorClass: 'text-red',
            filter: filterCloudUrls,
            darkMode: darkMode) {
    super.element.setAttr('hidden');
    footer.removeAttribute('hidden');
    expandButton.onClick.listen((_) => _toggleExpanded());
  }

  @override
  void showOutput(String message, {bool error = false}) {
    super.showOutput(message, error: error);
    if (!_expanded) {
      unreadCounter.increment();
    }
  }

  @override
  void clear() {
    super.clear();
    unreadCounter.clear();
  }

  void open() {
    if (!_expanded) {
      _toggleExpanded();
    }
  }

  void close() {
    if (_expanded) {
      _toggleExpanded();
    }
  }

  void _toggleExpanded() {
    _expanded = !_expanded;
    if (_expanded) {
      _initSplitter();
      _splitter.setSizes([60, 40]);
      element.toggleAttr('hidden', false);
      expandIcon.element.innerText = 'expand_more';
      footer.toggleClass('footer-top-border', false);
      unreadCounter.clear();
    } else {
      _splitter.setSizes([100, 0]);
      element.toggleAttr('hidden', true);
      expandIcon.element.innerText = 'expand_less';
      footer.toggleClass('footer-top-border', true);
      try {
        _splitter.destroy();
      } on NoSuchMethodError {
        // dart2js throws NoSuchMethodError (dartdevc is ok)
        // TODO(ryjohn): why does this happen?
      }
    }
    onSizeChanged();
  }

  void _initSplitter() {
    final editorContainer = querySelector('#editor-container')!;
    final splitterElements = [
      editorContainer,
      querySelector('#console-output-footer')!,
    ];
    _splitter = flexSplit(
      splitterElements,
      horizontal: false,
      gutterSize: defaultSplitterWidth,
      sizes: [60, 40],
      minSize: [32, 32],
    );
    editorUi.listenForResize(editorContainer);
  }
}

class EmbedContext extends Context {
  final Editor editor;

  final _modeController = StreamController<String>.broadcast();

  final Document _dartDoc;
  final Document _htmlDoc;
  final Document _cssDoc;
  final Document _testDoc;
  final Document _solutionDoc;

  bool _testAndSolutionReadOnly;

  String hint = '';

  String _solution = '';

  String get testMethod => testSource;

  set testMethod(String value) {
    testSource = value;
  }

  String get solution => _solution;

  set solution(String value) {
    _solution = value;
    solutionSource = value;
  }

  final _dartDirtyController = StreamController.broadcast();

  final _dartReconcileController = StreamController.broadcast();

  EmbedContext(this.editor, this._testAndSolutionReadOnly)
      : _dartDoc = editor.document,
        _htmlDoc = editor.createDocument(content: '', mode: 'html'),
        _cssDoc = editor.createDocument(content: '', mode: 'css'),
        _testDoc = editor.createDocument(content: '', mode: 'dart'),
        _solutionDoc = editor.createDocument(content: '', mode: 'dart') {
    editor.mode = 'dart';
    _dartDoc.onChange.listen((_) => _dartDirtyController.add(null));
    _createReconciler(_dartDoc, _dartReconcileController, 1250);
  }

  Document get dartDocument => _dartDoc;

  @override
  String get dartSource => _dartDoc.value;

  @override
  String get htmlSource => _htmlDoc.value;

  @override
  String get cssSource => _cssDoc.value;

  String get testSource => _testDoc.value;

  String get solutionSource => _solutionDoc.value;

  @override
  set dartSource(String value) {
    _dartDoc.value = value;
    _dartDocLineCount = countLinesInString(value);
  }

  @override
  set htmlSource(String value) {
    _htmlDoc.value = value;
  }

  @override
  set cssSource(String value) {
    _cssDoc.value = value;
  }

  set testSource(String value) {
    _testDoc.value = value;
  }

  set solutionSource(String value) {
    _solutionDoc.value = value;
  }

  int _dartDocLineCount = 0;

  int get dartSourceLineCount => _dartDocLineCount;

  Document get htmlDocument => _htmlDoc;

  Document get cssDocument => _cssDoc;

  Document get testDocument => _testDoc;

  Document get solutionDocument => _solutionDoc;

  @override
  Stream<String> get onModeChange => _modeController.stream;

  bool get testAndSolutionReadOnly => _testAndSolutionReadOnly;

  set testAndSolutionReadOnly(bool readOnly) {
    _testAndSolutionReadOnly = readOnly;
    if (focusedEditor == 'test' || focusedEditor == 'solution') {
      editor.readOnly = testAndSolutionReadOnly;
    }
  }

  bool hasWebContent() {
    return htmlSource.trim().isNotEmpty || cssSource.trim().isNotEmpty;
  }

  @override
  void switchTo(String name) {
    final oldMode = activeMode;

    if (name == 'dart') {
      editor.swapDocument(_dartDoc);
      editor.readOnly = false;
      editor.autoCloseBrackets = false;
    } else if (name == 'html') {
      editor.swapDocument(_htmlDoc);
      editor.readOnly = false;
      editor.autoCloseBrackets = true;
    } else if (name == 'css') {
      editor.swapDocument(_cssDoc);
      editor.readOnly = false;
      editor.autoCloseBrackets = true;
    } else if (name == 'test') {
      editor.swapDocument(_testDoc);
      editor.readOnly = testAndSolutionReadOnly;
      editor.autoCloseBrackets = true;
    } else if (name == 'solution') {
      editor.swapDocument(_solutionDoc);
      editor.readOnly = testAndSolutionReadOnly;
      editor.autoCloseBrackets = true;
    }

    if (oldMode != name) _modeController.add(name);

    editor.focus();
  }

  /// return and indicator of the active tab one of these: EmbedContext.dartTabPrefix,
  @override
  String get focusedEditor {
    if (editor.document == _testDoc) return 'test';
    if (editor.document == _solutionDoc) return 'solution';
    if (editor.document == _htmlDoc) return 'html';
    if (editor.document == _cssDoc) return 'css';
    return 'dart';
  }

  @override
  String get activeMode => editor.mode;

  Stream get onDartDirty => _dartDirtyController.stream;

  Stream get onDartReconcile => _dartReconcileController.stream;

  void markDartClean() => _dartDoc.markClean();

  /// Restore the focus to the last focused editor.
  void focus() => editor.focus();

  void _createReconciler(Document doc, StreamController controller, int delay) {
    Timer? timer;
    doc.onChange.listen((_) {
      timer?.cancel();
      timer = Timer(Duration(milliseconds: delay), () {
        controller.add(null);
      });
    });
  }

  /// Return true if the current cursor position is in a whitespace char.
  bool cursorPositionIsWhitespace() {
    final document = editor.document;
    final str = document.value;
    final index = document.indexFromPos(document.cursor);
    if (index < 0 || index >= str.length) return false;
    final char = str[index];
    return char != char.trim();
  }

  @override
  bool get isFocused => focusedEditor == 'dart' && editor.hasFocus;

  /// Counts the number of lines in [str].
  static int countLinesInString(String str) =>
      LineSplitter().convert(str).length;
}

final RegExp _flutterUrlExp =
    RegExp(r'(https:[a-zA-Z0-9_=%&\/\-\?\.]+flutter_web\.js)(:\d+:\d+)');
final RegExp _dartUrlExp =
    RegExp(r'(https:[a-zA-Z0-9_=%&\/\-\?\.]+dart_sdk\.js)(:\d+:\d+)');

String filterCloudUrls(String trace) {
  return trace
      .replaceAllMapped(
          _flutterUrlExp, (m) => '[Flutter SDK Source]${m.group(2)}')
      .replaceAllMapped(_dartUrlExp, (m) => '[Dart SDK Source]${m.group(2)}');
}
