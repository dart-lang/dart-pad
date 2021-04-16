import 'dart:async';
import 'dart:html' hide Console;

import 'package:dart_pad/util/query_params.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:mdc_web/mdc_web.dart';
import 'package:split/split.dart';

import 'codelabs/codelabs.dart';
import 'core/dependencies.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'editing/codemirror_options.dart';
import 'editing/editor.dart';
import 'editing/editor_codemirror.dart';
import 'elements/button.dart';
import 'elements/console.dart';
import 'elements/counter.dart';
import 'elements/dialog.dart';
import 'elements/elements.dart';
import 'elements/material_tab_controller.dart';
import 'modules/codemirror_module.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'services/common.dart';
import 'services/dartservices.dart';
import 'services/execution.dart';
import 'services/execution_iframe.dart';
import 'src/ga.dart';

CodelabUi _codelabUi;

CodelabUi get codelabUi => _codelabUi;

void init() {
  _codelabUi = CodelabUi();
}

class CodelabUi {
  CodelabState _codelabState;
  Splitter splitter;
  Splitter rightSplitter;
  Editor editor;
  DElement stepLabel;
  DElement previousStepButton;
  DElement nextStepButton;
  Console _console;
  MDCButton runButton;
  MDCButton showSolutionButton;
  MaterialTabController consolePanelTabController;
  Counter unreadConsoleCounter;
  Dialog dialog;

  CodelabUi() {
    _init();
  }

  DivElement get _editorHost => querySelector('#editor-host') as DivElement;

  DivElement get _consoleElement =>
      querySelector('#output-panel-content') as DivElement;

  DivElement get _documentationElement =>
      querySelector('#doc-panel') as DivElement;

  IFrameElement get _frame => querySelector('#frame') as IFrameElement;

  Future<void> _init() async {
    _initDialogs();
    await _loadCodelab();
    _initHeader();
    _updateInstructions();
    await _initModules();
    _initCodelabUi();
    _initEditor();
    _initSplitters();
    _initStepButtons();
    _initStepListener();
    _initConsoles();
    _initButtons();
    _updateCode();
    _initTabs();
  }

  Future<void> _initModules() async {
    var modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());
    modules.register(CodeMirrorModule());

    await modules.start();
  }

  void _initDialogs() {
    dialog = Dialog();
  }

  void _initEditor() {
    // Set up CodeMirror
    editor = (editorFactory as CodeMirrorFactory)
        .createFromElement(_editorHost, options: codeMirrorOptions)
          ..theme = 'darkpad'
          ..mode = 'dart'
          ..showLineNumbers = true;
  }

  void _initCodelabUi() {
    // Set up the iframe.
    deps[ExecutionService] = ExecutionServiceIFrame(_frame);
    executionService.onStdout.listen(_showOutput);
    executionService.onStderr.listen((m) => _showOutput(m, error: true));
    // Set up Google Analytics.
    deps[Analytics] = Analytics();

    // Use null safety for codelabs
    (deps[DartservicesApi] as DartservicesApi).rootUrl = nullSafetyServerUrl;
  }

  Future<void> _loadCodelab() async {
    var fetcher = await _getFetcher();
    _codelabState = CodelabState(await fetcher.getCodelab());
  }

  void _initSplitters() {
    var stepsPanel = querySelector('#steps-panel');
    var rightPanel = querySelector('#right-panel');
    var editorPanel = querySelector('#editor-panel');
    var outputPanel = querySelector('#output-panel');
    splitter = flexSplit(
      [stepsPanel, rightPanel],
      horizontal: true,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: [100, 100],
    );
    rightSplitter = flexSplit(
      [editorPanel, outputPanel],
      horizontal: false,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: [100, 100],
    );

    // Resize Codemirror when the size of the panel changes. This keeps the
    // virtual scrollbar in sync with the size of the panel.
    ResizeObserver((entries, observer) {
      editor.resize();
    }).observe(editorPanel);
  }

  void _initHeader() {
    querySelector('#codelab-name').text = _codelabState.codelab.name;
  }

  void _initStepButtons() {
    stepLabel = DElement(querySelector('#steps-label'));
    previousStepButton = DElement(querySelector('#previous-step-btn'))
      ..onClick.listen((event) {
        _codelabState.currentStepIndex--;
      });
    nextStepButton = DElement(querySelector('#next-step-btn'))
      ..onClick.listen((event) {
        _codelabState.currentStepIndex++;
      });
    _updateStepButtons();
  }

  void _initStepListener() {
    _codelabState.onStepChanged.listen((event) {
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
      ..onClick.listen((_) => _handleRun());

    showSolutionButton =
        MDCButton(querySelector('#show-solution-btn') as ButtonElement)
          ..onClick.listen((_) => _handleShowSolution());
  }

  void _updateSolutionButton() {
    if (_codelabState.currentStep.solution == null) {
      showSolutionButton.element.style.visibility = 'hidden';
    } else {
      showSolutionButton.element.style.visibility = null;
    }
    showSolutionButton.disabled = false;
  }

  void _updateCode() {
    editor.document.updateValue(_codelabState.currentStep.snippet);
  }

  void _initTabs() {
    var consoleTabBar = querySelector('#web-tab-bar');
    consolePanelTabController = MaterialTabController(MDCTabBar(consoleTabBar));
    for (var name in ['ui-output', 'console', 'documentation']) {
      consolePanelTabController.registerTab(
          TabElement(querySelector('#$name-tab'), name: name, onSelect: () {
        _changeConsoleTab(name);
      }));
    }
    // Set the current tab to UI Output
    _changeConsoleTab('ui-output');
  }

  void _changeConsoleTab(String name) {
    if (name == 'ui-output') {
      _frame.hidden = false;
      _consoleElement.hidden = true;
      _documentationElement.hidden = true;
    } else if (name == 'console') {
      _frame.hidden = true;
      _consoleElement.hidden = false;
      _documentationElement.hidden = true;
    } else if (name == 'documentation') {
      _frame.hidden = true;
      _consoleElement.hidden = true;
      _documentationElement.hidden = false;
    }
  }

  void _updateInstructions() {
    var div = querySelector('#markdown-content');
    div.children.clear();
    div.innerHtml =
        markdown.markdownToHtml(_codelabState.currentStep.instructions);
  }

  void _updateStepButtons() {
    stepLabel.text = 'Step ${_codelabState.currentStepIndex + 1}';
    previousStepButton.toggleAttr('disabled', !_codelabState.hasPreviousStep);
    nextStepButton.toggleAttr('disabled', !_codelabState.hasNextStep);
  }

  Future<CodelabFetcher> _getFetcher() async {
    var webServer = queryParams.webServer;
    if (webServer != null && webServer.isNotEmpty) {
      var uri = Uri.parse(webServer);
      return WebServerCodelabFetcher(uri);
    }
    var ghOwner = queryParams.githubOwner;
    var ghRepo = queryParams.githubRepo;
    var ghRef = queryParams.githubRef;
    var ghPath = queryParams.githubPath;
    if (ghOwner != null &&
        ghOwner.isNotEmpty &&
        ghRepo != null &&
        ghRepo.isNotEmpty) {
      return GithubCodelabFetcher(
        owner: ghOwner,
        repo: ghRepo,
        ref: ghRef,
        path: ghPath,
      );
    }
    throw ('Invalid parameters provided. Use either "webserver" or '
        '"gh_owner", "gh_repo", "gh_ref", and "gh_path"');
  }

  void _handleRun() async {
    ga.sendEvent('main', 'run');
    runButton.disabled = true;

    var compilationTimer = Stopwatch()..start();

    final compileRequest = CompileRequest()..source = editor.document.value;

    try {
      if (_codelabState.codelab.type == CodelabType.flutter) {
        final response = await dartServices
            .compileDDC(compileRequest)
            .timeout(longServiceCallTimeout);

        ga.sendTiming(
          'action-perf',
          'compilation-e2e',
          compilationTimer.elapsedMilliseconds,
        );

        _clearOutput();

        await executionService.execute(
          '',
          '',
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

        await executionService.execute(
          '',
          '',
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
    }
  }

  void _clearOutput() {
    _console.clear();
    unreadConsoleCounter.clear();
  }

  void _showOutput(String message, {bool error = false}) {
    _console.showOutput(message, error: error);
    if (consolePanelTabController.selectedTab.name != 'console') {
      unreadConsoleCounter.increment();
    }
  }

  void _showSnackbar(String message) {
    var div = querySelector('.mdc-snackbar');
    var snackbar = MDCSnackbar(div)..labelText = message;
    snackbar.open();
  }

  Future<void> _handleShowSolution() async {
    var result = await dialog.showOkCancel(
        'Show solution',
        'Are you sure you want to show the solution? Your changes for this '
            'step will be lost.');
    if (result == DialogResult.ok) {
      editor.document.updateValue(_codelabState.currentStep.solution);
      showSolutionButton.disabled = true;
    }
  }
}

class CodelabState {
  final StreamController<Step> _controller = StreamController.broadcast();
  int _currentStepIndex = 0;

  final Codelab codelab;

  CodelabState(this.codelab);

  Stream<Step> get onStepChanged => _controller.stream;

  Step get currentStep => codelab.steps[_currentStepIndex];

  int get currentStepIndex => _currentStepIndex;

  set currentStepIndex(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= codelab.steps.length) {
      throw ('Invalid step index: $stepIndex');
    }
    _currentStepIndex = stepIndex;
    _controller.add(codelab.steps[stepIndex]);
  }

  bool get hasNextStep => _currentStepIndex < codelab.steps.length - 1;

  bool get hasPreviousStep => _currentStepIndex > 0;
}
