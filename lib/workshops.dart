import 'dart:async';
import 'dart:html' hide Console;

import 'package:dart_pad/context.dart';
import 'package:dart_pad/src/util.dart';
import 'package:dart_pad/util/detect_flutter.dart';
import 'package:dart_pad/util/query_params.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:mdc_web/mdc_web.dart';
import 'package:split/split.dart';
import 'package:stream_transform/stream_transform.dart';

import 'completion.dart';
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
import 'elements/material_tab_controller.dart';
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
import 'util/keymap.dart';
import 'workshops/workshops.dart';

WorkshopUi _workshopUi;

WorkshopUi get workshopUi => _workshopUi;

final NodeValidator _htmlValidator = PermissiveNodeValidator();

void init() {
  _workshopUi = WorkshopUi();
}

class WorkshopUi extends EditorUi {
  WorkshopState _workshopState;
  Splitter splitter;
  Splitter rightSplitter;
  DElement stepLabel;
  DElement previousStepButton;
  DElement nextStepButton;
  Console _console;
  MDCButton showSolutionButton;
  MaterialTabController consolePanelTabController;
  Counter unreadConsoleCounter;
  Dialog dialog;
  DocHandler docHandler;
  @override
  ContextBase context;
  MDCButton formatButton;
  TabExpandController tabExpandController;
  MDCButton closePanelButton;
  MDCButton editorUiOutputTab;
  MDCButton editorConsoleTab;
  MDCButton editorDocsTab;

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
    _initDialogs();
    await _loadWorkshop();
    _initBusyLights();
    _initHeader();
    _updateInstructions();
    await _initModules();
    _initWorkshopUi();
    _initKeyBindings();
    _initEditor();
    _initSplitters();
    _initStepButtons();
    _initStepListener();
    _initConsoles();
    _initButtons();
    _updateCode();
    // _initTabs();
    _focusEditor();
    _initOutputPanelTabs();
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

  void _initBusyLights() {
    busyLight = DBusyLight(querySelector('#dartbusy'));
  }

  void _initEditor() {
    // Set up CodeMirror
    editor = (editorFactory as CodeMirrorFactory)
        .createFromElement(_editorHost, options: codeMirrorOptions)
          ..theme = 'darkpad'
          ..mode = 'dart'
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
    (deps[DartservicesApi] as DartservicesApi).rootUrl = nullSafetyServerUrl;

    analysisResultsController = AnalysisResultsController(
        DElement(querySelector('#issues')),
        DElement(querySelector('#issues-message')),
        DElement(querySelector('#issues-toggle')))
      ..onItemClicked.listen((item) {
        _jumpTo(item.line, item.charStart, item.charLength, focus: true);
      });

    _updateVersion();

    querySelector('#keyboard-button')
        .onClick
        .listen((_) => _showKeyboardDialog());
  }

  void _initKeyBindings() {
    // set up key bindings
    keys.bind(['ctrl-enter'], handleRun, 'Run');
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

    keys.bind(['shift-ctrl-/', 'shift-macctrl-/'], () {
      _showKeyboardDialog();
    }, 'Keyboard Shortcuts');
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
  }

  void _handleAutoCompletion(KeyboardEvent e) {
    if (editor.hasFocus) {
      if (e.keyCode == KeyCode.PERIOD) {
        editor.showCompletions(autoInvoked: true);
      }
    }
  }

  void _updateVersion() {
    dartServices.version().then((VersionResponse version) {
      // "Based on Flutter 1.19.0-4.1.pre Dart SDK 2.8.4"
      var versionText = 'Based on Flutter ${version.flutterVersion}'
          ' Dart SDK ${version.sdkVersionFull}';
      querySelector('#dartpad-version').text = versionText;
    }).catchError((e) => null);
  }

  Future<void> _loadWorkshop() async {
    var fetcher = _createWorkshopFetcher();
    _workshopState = WorkshopState(await fetcher.fetch());
  }

  void _initSplitters() {
    var stepsPanel = querySelector('#steps-panel');
    var rightPanel = querySelector('#right-panel');
    var editorPanel = querySelector('#editor-panel');
    // var editorPanelFooter = querySelector('#editor-panel-footer');
    splitter = flexSplit(
      [stepsPanel, rightPanel],
      horizontal: true,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: [100, 100],
    );
    // rightSplitter = flexSplit(
    //   [editorPanel, editorPanelFooter],
    //   horizontal: false,
    //   gutterSize: 6,
    //   sizes: const [50, 50],
    //   minSize: [100, 100],
    // );

    // Resize Codemirror when the size of the panel changes. This keeps the
    // virtual scrollbar in sync with the size of the panel.
    ResizeObserver((entries, observer) {
      editor.resize();
    }).observe(editorPanel);
  }

  void _initHeader() {
    querySelector('#workshop-name').text = _workshopState.workshop.name;
  }

  void _initStepButtons() {
    stepLabel = DElement(querySelector('#steps-label'));
    previousStepButton = DElement(querySelector('#previous-step-btn'))
      ..onClick.listen((event) {
        _workshopState.currentStepIndex--;
      });
    nextStepButton = DElement(querySelector('#next-step-btn'))
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
    closePanelButton = MDCButton(
        querySelector('#editor-panel-close-button') as ButtonElement,
        isIcon: true);
    editorUiOutputTab =
        MDCButton(querySelector('#editor-panel-ui-tab') as ButtonElement);
    editorConsoleTab =
        MDCButton(querySelector('#editor-panel-console-tab') as ButtonElement);
    editorDocsTab =
        MDCButton(querySelector('#editor-panel-docs-tab') as ButtonElement);

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

  // void _initTabs() {
  //   var consoleTabBar = querySelector('#web-tab-bar');
  //   consolePanelTabController = MaterialTabController(MDCTabBar(consoleTabBar));
  //   for (var name in ['ui-output', 'console', 'documentation']) {
  //     consolePanelTabController.registerTab(
  //         TabElement(querySelector('#$name-tab'), name: name, onSelect: () {
  //       _changeConsoleTab(name);
  //     }));
  //   }
  //
  //   // Set the current tab to UI Output or console, depending on whether this is
  //   // Dart or Flutter workshop.
  //   if (_workshopState.workshop.type == WorkshopType.dart) {
  //     querySelector('#ui-output-tab').hidden = true;
  //     consolePanelTabController.selectTab('console');
  //   } else {
  //     consolePanelTabController.selectTab('ui-output');
  //   }
  // }

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
    div.setInnerHtml(
        markdown.markdownToHtml(_workshopState.currentStep.instructions),
        validator: _htmlValidator);
    hljs.highlightAll();
  }

  void _updateStepButtons() {
    stepLabel.text = 'Step ${_workshopState.currentStepIndex + 1}';
    previousStepButton.toggleAttr('disabled', !_workshopState.hasPreviousStep);
    nextStepButton.toggleAttr('disabled', !_workshopState.hasNextStep);
  }

  WorkshopFetcher _createWorkshopFetcher() {
    var webServer = queryParams.webServer;
    if (webServer != null && webServer.isNotEmpty) {
      var uri = Uri.parse(webServer);
      return WebServerWorkshopFetcher(uri);
    }
    var ghOwner = queryParams.githubOwner;
    var ghRepo = queryParams.githubRepo;
    var ghRef = queryParams.githubRef;
    var ghPath = queryParams.githubPath;
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

  void _showKeyboardDialog() {
    dialog.showOk('Keyboard shortcuts', keyMapToHtml(keys.inverseBindings));
  }

  Future<void> _format() {
    var originalSource = context.dartSource;
    var input = SourceRequest()..source = originalSource;
    formatButton.disabled = true;

    var request = dartServices.format(input).timeout(serviceCallTimeout);
    return request.then((FormatResponse result) {
      busyLight.reset();
      formatButton.disabled = false;

      if (result.newString == null || result.newString.isEmpty) {
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
    if (tabExpandController != null) {
      return;
    }

    tabExpandController = TabExpandController(
      consoleButton: editorConsoleTab,
      docsButton: editorDocsTab,
      closeButton: closePanelButton,
      docsElement: _documentationElement,
      consoleElement: _consoleElement,
      topSplit: _editorPanel,
      bottomSplit: _editorPanelFooter,
      unreadCounter: unreadConsoleCounter,
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
    if (consolePanelTabController.selectedTab.name != 'console') {
      unreadConsoleCounter.increment();
    }
  }

  Future<void> _handleShowSolution() async {
    var result = await dialog.showOkCancel(
        'Show solution',
        'Are you sure you want to show the solution? Your changes for this '
            'step will be lost.');
    if (result == DialogResult.ok) {
      editor.document.updateValue(_workshopState.currentStep.solution);
      showSolutionButton.disabled = true;
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
    var document = editor.document;
    var str = document.value;
    var index = document.indexFromPos(document.cursor);
    if (index < 0 || index >= str.length) return false;
    var char = str[index];
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
