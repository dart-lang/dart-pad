// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Console;

import 'package:markdown/markdown.dart' as markdown;
import 'package:split/split.dart';
import 'package:stream_transform/stream_transform.dart';

import 'completion.dart';
import 'context.dart';
import 'core/dependencies.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'documentation.dart';
import 'editing/codemirror_options.dart';
import 'editing/editor_codemirror.dart';
import 'elements/analysis_results_controller.dart';
import 'elements/button.dart';
import 'elements/console.dart';
import 'elements/counter.dart';
import 'elements/dialog.dart';
import 'elements/elements.dart';
import 'elements/tab_expand_controller.dart';
import 'hljs.dart' as hljs;
import 'modules/codemirror_module.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'services/common.dart';
import 'services/dartservices.dart';
import 'services/execution_iframe.dart';
import 'sharing/editor_ui.dart';
import 'src/ga.dart';
import 'src/util.dart';
import 'util/detect_flutter.dart';
import 'util/query_params.dart';
import 'workshops/workshops.dart';

WorkshopUi? _workshopUi;

WorkshopUi? get workshopUi => _workshopUi;

final NodeValidator _htmlValidator = PermissiveNodeValidator();

void init() {
  _workshopUi = WorkshopUi();
}

class WorkshopUi extends EditorUi {
  late final WorkshopState _workshopState;
  late final Splitter splitter;
  late final Splitter rightSplitter;
  late final DElement stepLabel;
  late final DElement previousStepButton;
  late final DElement nextStepButton;
  late final Console _console;
  late final MDCButton showSolutionButton;
  late final Counter unreadConsoleCounter;
  late final DocHandler docHandler;
  @override
  late ContextBase context;
  late MDCButton formatButton;
  late final TabExpandController tabExpandController;
  late final MDCButton clearConsoleButton;
  late final MDCButton closePanelButton;
  late final MDCButton editorUiOutputTab;
  late final MDCButton editorConsoleTab;
  late final MDCButton editorDocsTab;

  WorkshopUi() {
    _init();
  }

  DivElement get _editorPanel => querySelector('#editor-panel') as DivElement;

  DivElement get _editorHost => querySelector('#editor-host') as DivElement;

  IFrameElement get _frame => querySelector('#frame') as IFrameElement;

  DivElement get _consoleElement =>
      querySelector('#console-panel') as DivElement;

  DivElement get _documentationElement =>
      querySelector('#doc-panel') as DivElement;

  DivElement get _editorPanelFooter =>
      querySelector('#editor-panel-footer') as DivElement;

  Future<void> _init() async {
    await _loadWorkshop();
    _initBusyLights();
    _initHeader();
    _updateInstructions();
    await _initModules();
    _initWorkshopUi();
    initKeyBindings();
    _initEditor();
    _initSplitters();
    _initStepButtons();
    _initStepListener();
    _initConsoles();
    _initButtons();
    _updateCode();
    _updateSolutionButton();
    _focusEditor();
    _initOutputPanelTabs();
  }

  Future<void> _initModules() async {
    final modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());
    modules.register(CodeMirrorModule());

    await modules.start();
  }

  void _initBusyLights() {
    busyLight = DBusyLight(querySelector('#dartbusy')!);
  }

  void _initEditor() {
    // Set up CodeMirror
    editor = (editorFactory as CodeMirrorFactory)
        .createFromElement(_editorHost, options: codeMirrorOptions)
      ..theme = 'darkpad'
      ..mode = 'dart'
      ..keyMap = window.localStorage['codemirror_keymap'] ?? 'default'
      ..showLineNumbers = true;

    context = WorkshopDartSourceProvider(editor);
    docHandler = DocHandler(editor, context);

    editor.document.onChange.listen((_) => busyLight.on());
    editor.document.onChange
        .debounce(Duration(milliseconds: 1250))
        .listen((_) => performAnalysis());

    editorFactory.registerCompleter(
        'dart', DartCompleter(dartServices, editor.document));

    // Listen for changes that would effect the documentation panel.
    editor.onMouseDown.listen((e) {
      // Delay to give codemirror time to process the mouse event.
      Timer.run(() {
        if (!_cursorPositionIsWhitespace()) {
          docHandler.generateDoc([_documentationElement]);
        }
      });
    });
  }

  void _initWorkshopUi() {
    // Set up the iframe.
    executionService = ExecutionServiceIFrame(_frame);
    executionService.onStdout.listen(showOutput);
    executionService.onStderr.listen((m) => showOutput(m, error: true));
    // Set up Google Analytics.
    deps[Analytics] = Analytics();

    // Use null safety for workshops
    (deps[DartservicesApi] as DartservicesApi).rootUrl = serverUrl;

    analysisResultsController = AnalysisResultsController(
      DElement(querySelector('#issues')!),
      DElement(querySelector('#issues-message')!),
      DElement(querySelector('#issues-toggle')!),
      snackbar,
    )..onItemClicked.listen((item) {
        _jumpTo(item.line, item.charStart, item.charLength, focus: true);
      });

    updateVersions();

    querySelector('#keyboard-button')
        ?.onClick
        .listen((_) => showKeyboardDialog());
    querySelector('#dartpad-package-versions')
        ?.onClick
        .listen((_) => showPackageVersionsDialog());
  }

  @override
  void initKeyBindings() {
    keys.bind(['f1'], () {
      ga.sendEvent('main', 'help');
      docHandler.generateDoc([_documentationElement]);
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
        docHandler.generateDoc([_documentationElement]);
      }
      _handleAutoCompletion(e);
    });

    super.initKeyBindings();
  }

  void _handleAutoCompletion(KeyboardEvent e) {
    if (editor.hasFocus) {
      if (e.keyCode == KeyCode.PERIOD) {
        editor.showCompletions(autoInvoked: true);
      }
    }
  }

  Future<void> _loadWorkshop() async {
    final fetcher = _createWorkshopFetcher();
    _workshopState = WorkshopState(await fetcher.fetch());
  }

  void _initSplitters() {
    final stepsPanel = querySelector('#steps-panel');
    final rightPanel = querySelector('#right-panel');
    final editorPanel = querySelector('#editor-panel')!;

    splitter = flexSplit(
      [stepsPanel!, rightPanel!],
      horizontal: true,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: [100, 100],
    );

    listenForResize(editorPanel);
  }

  void _initHeader() {
    querySelector('#workshop-name')!.text = _workshopState.workshop.name;
  }

  void _initStepButtons() {
    stepLabel = DElement(querySelector('#steps-label')!);
    previousStepButton = DElement(querySelector('#previous-step-btn')!)
      ..onClick.listen((event) {
        _workshopState.currentStepIndex--;
      });
    nextStepButton = DElement(querySelector('#next-step-btn')!)
      ..onClick.listen((event) {
        _workshopState.currentStepIndex++;
      });
    _updateStepButtons();
  }

  void _initStepListener() {
    _workshopState.onStepChanged.listen((event) {
      _updateInstructions();
      _updateStepButtons();
      _updateCode();
      _updateSolutionButton();
    });
  }

  void _initConsoles() {
    _console = Console(DElement(_consoleElement));
    unreadConsoleCounter =
        Counter(querySelector('#unread-console-counter') as SpanElement);
  }

  void _initButtons() {
    runButton = MDCButton(querySelector('#run-button') as ButtonElement)
      ..onClick.listen((_) => handleRun());

    showSolutionButton =
        MDCButton(querySelector('#show-solution-btn') as ButtonElement)
          ..onClick.listen((_) => _handleShowSolution());
    formatButton = MDCButton(querySelector('#format-button') as ButtonElement)
      ..onClick.listen((_) => _format());
    clearConsoleButton = MDCButton(
        querySelector('#left-console-clear-button') as ButtonElement,
        isIcon: true)
      ..onClick.listen((_) => clearOutput());
    closePanelButton = MDCButton(
        querySelector('#editor-panel-close-button') as ButtonElement,
        isIcon: true);
    editorUiOutputTab =
        MDCButton(querySelector('#editor-panel-ui-tab') as ButtonElement);
    editorConsoleTab =
        MDCButton(querySelector('#editor-panel-console-tab') as ButtonElement);
    editorDocsTab =
        MDCButton(querySelector('#editor-panel-docs-tab') as ButtonElement);
    if (!shouldCompileDDC) {
      editorUiOutputTab.setAttr('hidden');
    }
  }

  void _updateSolutionButton() {
    if (_workshopState.currentStep.solution == null) {
      showSolutionButton.element.style.visibility = 'hidden';
    } else {
      showSolutionButton.element.style.visibility = null;
    }
    showSolutionButton.disabled = false;
  }

  void _updateCode() {
    editor.document.updateValue(_workshopState.currentStep.snippet);
  }

  void _updateInstructions() {
    final div = querySelector('#markdown-content')!;
    div.children.clear();
    div.setInnerHtml(
        markdown.markdownToHtml(_workshopState.currentStep.instructions,
            blockSyntaxes: [markdown.TableSyntax()]),
        validator: _htmlValidator);
    print('highlightAll()');
    hljs.highlightAll();
    div.scrollTop = 0;
  }

  void _updateStepButtons() {
    stepLabel.text = 'Step ${_workshopState.currentStepIndex + 1}';
    previousStepButton.toggleAttr('disabled', !_workshopState.hasPreviousStep);
    nextStepButton.toggleAttr('disabled', !_workshopState.hasNextStep);
  }

  WorkshopFetcher _createWorkshopFetcher() {
    final webServer = queryParams.webServer;
    if (webServer != null && webServer.isNotEmpty) {
      final uri = Uri.parse(webServer);
      return WebServerWorkshopFetcher(uri);
    }
    final ghOwner = queryParams.githubOwner;
    final ghRepo = queryParams.githubRepo;
    final ghRef = queryParams.githubRef;
    final ghPath = queryParams.githubPath;
    if (ghOwner != null &&
        ghOwner.isNotEmpty &&
        ghRepo != null &&
        ghRepo.isNotEmpty) {
      return GithubWorkshopFetcher(
        owner: ghOwner,
        repo: ghRepo,
        ref: ghRef,
        path: ghPath,
      );
    }
    throw ('Invalid parameters provided. Use either "webserver" or '
        '"gh_owner", "gh_repo", "gh_ref", and "gh_path"');
  }

  Future<void> _format() {
    final originalSource = context.dartSource;
    final input = SourceRequest()..source = originalSource;
    formatButton.disabled = true;

    final request = dartServices.format(input).timeout(serviceCallTimeout);
    return request.then((FormatResponse result) {
      busyLight.reset();
      formatButton.disabled = false;

      if (result.newString.isEmpty) {
        logger.fine('Format returned null/empty result');
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
      logger.severe(e);
    });
  }

  void _initOutputPanelTabs() {
    tabExpandController = TabExpandController(
      uiOutputButton: shouldCompileDDC ? editorUiOutputTab : null,
      consoleButton: editorConsoleTab,
      docsButton: editorDocsTab,
      clearConsoleButton: clearConsoleButton,
      closeButton: closePanelButton,
      iframeElement: _frame,
      docsElement: _documentationElement,
      consoleElement: _consoleElement,
      topSplit: _editorPanel,
      bottomSplit: _editorPanelFooter,
      unreadCounter: unreadConsoleCounter,
      editorUi: this,
    );
  }

  void _focusEditor() {
    editor.focus();
  }

  @override
  bool get shouldCompileDDC =>
      _workshopState.workshop.type == WorkshopType.flutter;

  @override
  bool get shouldAddFirebaseJs => hasFirebaseContent(editor.document.value);

  @override
  void clearOutput() {
    _console.clear();
    unreadConsoleCounter.clear();
  }

  @override
  void showOutput(String message, {bool error = false}) {
    _console.showOutput(message, error: error);
    if (tabExpandController.state != TabState.console) {
      unreadConsoleCounter.increment();
    }
  }

  Future<void> _handleShowSolution() async {
    final solution = _workshopState.currentStep.solution;

    if (solution == null) {
      showSnackbar('This step has no solution.');
    } else {
      final result = await dialog.showOkCancel(
          'Show solution',
          'Are you sure you want to show the solution? Your changes for this '
              'step will be lost.');
      if (result == DialogResult.ok) {
        editor.document.updateValue(solution);
        showSolutionButton.disabled = true;
      }
    }
  }

  void _jumpTo(int line, int charStart, int charLength, {bool focus = false}) {
    final doc = editor.document;

    doc.select(
        doc.posFromIndex(charStart), doc.posFromIndex(charStart + charLength));

    if (focus) editor.focus();
  }

  /// Return true if the current cursor position is in a whitespace char.
  bool _cursorPositionIsWhitespace() {
    final document = editor.document;
    final str = document.value;
    final index = document.indexFromPos(document.cursor);
    if (index < 0 || index >= str.length) return false;
    final char = str[index];
    return char != char.trim();
  }
}

class WorkshopState {
  final StreamController<Step> _controller = StreamController.broadcast();
  int _currentStepIndex = 0;

  final Workshop workshop;

  WorkshopState(this.workshop);

  Stream<Step> get onStepChanged => _controller.stream;

  Step get currentStep => workshop.steps[_currentStepIndex];

  int get currentStepIndex => _currentStepIndex;

  set currentStepIndex(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= workshop.steps.length) {
      throw ('Invalid step index: $stepIndex');
    }
    _currentStepIndex = stepIndex;
    _controller.add(workshop.steps[stepIndex]);
  }

  bool get hasNextStep => _currentStepIndex < workshop.steps.length - 1;

  bool get hasPreviousStep => _currentStepIndex > 0;
}

class WorkshopDartSourceProvider implements ContextBase {
  final Editor editor;

  WorkshopDartSourceProvider(this.editor);

  @override
  String get dartSource => editor.document.value;

  @override
  String get htmlSource => '';

  @override
  String get cssSource => '';

  @override
  bool get isFocused => true;
}
