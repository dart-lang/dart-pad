// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Document;

import 'package:dart_pad/sharing/gists.dart';

import '../core/dependencies.dart';
import '../core/modules.dart';
import '../editing/editor.dart';
import '../editing/editor_codemirror.dart';
import '../elements/elements.dart';
import '../modules/dart_pad_module.dart';
import '../modules/dartservices_module.dart';
import '../services/common.dart';
import '../services/dartservices.dart';
import '../services/execution_iframe.dart';
import '../src/util.dart';

NewEmbed get newEmbed => _newEmbed;

NewEmbed _newEmbed;

void init() {
  _newEmbed = NewEmbed();
}

/// An embeddable DartPad UI that provides the ability to test the user's code
/// snippet against a desired result.
class NewEmbed {
  ExecuteCodeButton executeButton;
  ButtonElement reloadGistButton;

  TabController tabController;
  TabView editorTabView;
  TabView testTabView;
  ConsoleTabView consoleTabView;

  Counter unreadConsoleCounter;

  FlashBox testResultBox;
  FlashBox analysisResultBox;

  ExecutionService executionSvc;

  EditorFactory editorFactory = codeMirrorFactory;

  Editor testEditor;
  Editor userCodeEditor;

  NewEmbedContext context;

  final _debounceTimer = DelayedTimer(
    minDelay: Duration(milliseconds: 100),
    maxDelay: Duration(milliseconds: 500),
  );

  NewEmbed() {
    tabController = NewEmbedTabController();
    for (String name in ['editor', 'test', 'console']) {
      tabController.registerTab(
        TabElement(querySelector('#$name-tab'), name: name, onSelect: () {
          editorTabView.setSelected(name == 'editor');
          testTabView.setSelected(name == 'test');
          consoleTabView.setSelected(name == 'console');

          if (name == 'editor') {
            userCodeEditor.resize();
            userCodeEditor.focus();
          } else if (name == 'test') {
            testEditor.resize();
            testEditor.focus();
          } else {
            // Must be the console tab.
            unreadConsoleCounter.clear();
          }
        }),
      );
    }

    unreadConsoleCounter = Counter(querySelector('#unread-console-counter'));

    executeButton =
        ExecuteCodeButton(querySelector('#execute'), _handleExecute);

    reloadGistButton = querySelector('#reload-gist');
    if (gistId.isNotEmpty) {
      reloadGistButton.onClick.listen((e) => _loadAndShowGist(gistId));
    } else {
      reloadGistButton.setAttribute('disabled', 'true');
    }

    testResultBox = FlashBox(querySelector('#test-result-box'));
    analysisResultBox = FlashBox(querySelector('#analysis-result-box'));

    userCodeEditor =
        editorFactory.createFromElement(querySelector('#user-code-editor'))
          ..theme = 'elegant'
          ..mode = 'dart'
          ..showLineNumbers = true;

    userCodeEditor.document.onChange.listen(_performAnalysis);

    testEditor = editorFactory.createFromElement(querySelector('#test-editor'))
      ..theme = 'elegant'
      ..mode = 'dart'
      ..showLineNumbers = true;

    editorTabView = TabView(DElement(querySelector('#user-code-view')));

    testTabView = TabView(DElement(querySelector('#test-view')));

    consoleTabView = ConsoleTabView(DElement(querySelector('#console-view')));

    executionSvc = ExecutionServiceIFrame(querySelector('#frame'));

    executionSvc.onStderr.listen((err) {
      if (tabController.selectedTab.name != 'console') {
        unreadConsoleCounter.increment();
      }
      consoleTabView.appendError(err);
    });

    executionSvc.onStdout.listen((msg) {
      if (tabController.selectedTab.name != 'console') {
        unreadConsoleCounter.increment();
      }
      consoleTabView.appendMessage(msg);
    });

    executionSvc.testResults.listen((result) {
      if (result.success) {
        executeButton.executionState = ExecutionState.testSuccess;
      }

      testResultBox.showStrings(
        result.messages.isNotEmpty ? result.messages : ['Test passed!'],
        result.success ? FlashBoxStyle.success : FlashBoxStyle.warn,
      );
    });

    _initModules().then((_) => _initNewEmbed());
  }

  String get gistId {
    Uri url = Uri.parse(window.location.toString());

    if (url.hasQuery &&
        url.queryParameters['id'] != null &&
        isLegalGistId(url.queryParameters['id'])) {
      return url.queryParameters['id'];
    }

    return '';
  }

  Future<void> _initModules() async {
    ModuleManager modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());

    await modules.start();
  }

  void _initNewEmbed() {
    deps[GistLoader] = GistLoader.defaultFilters();

    context = NewEmbedContext(userCodeEditor, testEditor);

    if (gistId.isNotEmpty) {
      _loadAndShowGist(gistId);
    }
  }

  Future<void> _loadAndShowGist(String id) async {
    final GistLoader loader = deps[GistLoader];
    final gist = await loader.loadGist(id);
    context.dartSource = gist.getFile('main.dart')?.content ?? '';
    context.testMethod = gist.getFile('test.dart')?.content ?? '';
  }

  void _handleExecute() {
    executeButton.executionState = ExecutionState.executing;
    testResultBox.hide();
    consoleTabView.clear();

    final fullCode =
        '${context.dartSource}\n${context.testMethod}\n${executionSvc.testResultDecoration}';

    var input = CompileRequest()..source = fullCode;

    deps[DartservicesApi]
        .compile(input)
        .timeout(longServiceCallTimeout)
        .then((CompileResponse response) {
      executionSvc.execute('', '', response.result);
    }).catchError((e) {
      consoleTabView.appendError('Error compiling to JavaScript:\n$e');
      tabController.selectTab('console');
    }).whenComplete(() {
      executeButton.executionState = ExecutionState.ready;
    });
  }

  void _displayIssues(List<AnalysisIssue> issues) {
    final elements = <DivElement>[];

    for (AnalysisIssue issue in issues) {
      elements.add(
        DivElement()
          ..children.add(
            AnchorElement()
              ..text = '${issue.kind.toUpperCase()} - ${issue.message}'
              ..classes = ['link-message', 'text-red']
              ..onClick.listen((event) {
                _jumpTo(issue.line, issue.charStart, issue.charLength,
                    focus: true);
              }),
          ),
      );
    }

    if (elements.isNotEmpty) {
      analysisResultBox.showElements(elements, FlashBoxStyle.error);
    } else {
      analysisResultBox.hide();
    }
  }

  void _jumpTo(int line, int charStart, int charLength, {bool focus = false}) {
    Document doc = userCodeEditor.document;

    doc.select(
        doc.posFromIndex(charStart), doc.posFromIndex(charStart + charLength));

    if (focus) userCodeEditor.focus();
  }

  /// Perform static analysis of the source code.
  void _performAnalysis(_) async {
    _debounceTimer.invoke(() {
      final dartServices = deps[DartservicesApi] as DartservicesApi;
      final input = SourceRequest()..source = userCodeEditor.document.value;
      final lines = Lines(input.source);
      final request = dartServices.analyze(input).timeout(serviceCallTimeout);

      request.then((AnalysisResults result) {
        // Discard if the document has been mutated since we requested analysis.
        if (input.source != userCodeEditor.document.value) return false;

        _displayIssues(result.issues);

        userCodeEditor.document
            .setAnnotations(result.issues.map((AnalysisIssue issue) {
          final startLine = lines.getLineForOffset(issue.charStart);
          final endLine =
              lines.getLineForOffset(issue.charStart + issue.charLength);

          return Annotation(
            issue.kind,
            issue.message,
            issue.line,
            start: Position(
              startLine,
              issue.charStart - lines.offsetForLine(startLine),
            ),
            end: Position(
              endLine,
              issue.charStart +
                  issue.charLength -
                  lines.offsetForLine(startLine),
            ),
          );
        }).toList());
      });
    });
  }
}

// Primer uses a class called "selected" for its navigation styling, rather than
// an attribute. This class extends the tab controller code to also toggle that
// class.
class NewEmbedTabController extends TabController {
  /// This method will throw if the tabName is not the name of a current tab.
  @override
  void selectTab(String tabName) {
    TabElement tab = tabs.firstWhere((t) => t.name == tabName);

    for (TabElement t in tabs) {
      t.toggleClass('selected', t == tab);
    }

    super.selectTab(tabName);
  }
}

/// A container underneath the tab strip that can show or hide itself as needed.
class TabView {
  final DElement element;

  const TabView(this.element);

  void setSelected(bool selected) {
    if (selected) {
      element.clearAttr('hidden');
    } else {
      element.setAttr('hidden');
    }
  }
}

class ConsoleTabView extends TabView {
  const ConsoleTabView(DElement element) : super(element);

  void clear() {
    element.text = '';
  }

  void appendMessage(String msg) {
    final line = DivElement()..text = msg;
    element.add(line);
  }

  void appendError(String err) {
    final line = DivElement()
      ..text = err
      ..classes.add('text-red');
    element.add(line);
  }
}

class Counter {
  Counter(this.element);

  final SpanElement element;

  int _itemCount = 0;

  void increment() {
    _itemCount++;
    element.text = _itemCount.toString();
    element.attributes.remove('hidden');
  }

  void clear() {
    _itemCount = 0;
    element.setAttribute('hidden', 'true');
  }
}

enum ExecutionState {
  ready,
  executing,
  testSuccess,
}

class ExecuteCodeButton {
  /// This constructor will throw if the provided element has no child with a
  /// CSS class that begins with "octicon-".
  ExecuteCodeButton(ButtonElement anchorElement, VoidCallback onClick)
      : assert(anchorElement != null),
        assert(onClick != null) {
    final iconElement =
        anchorElement.children.firstWhere(Octicon.elementIsOcticon);
    _icon = Octicon(iconElement);
    _element = DElement(anchorElement);
    _element.onClick.listen((e) => onClick());
  }

  static const iconNames = <ExecutionState, String>{
    ExecutionState.ready: 'triangle-right',
    ExecutionState.executing: 'sync',
    ExecutionState.testSuccess: 'check',
  };

  static const disabledClassName = 'disabled';

  DElement _element;

  Octicon _icon;

  set executionState(ExecutionState state) {
    _element.toggleClass(disabledClassName, state == ExecutionState.executing);
    _icon.iconName = iconNames[state];
  }
}

class Octicon {
  static const prefix = 'octicon-';

  Octicon(this.element);

  final DivElement element;

  String get iconName {
    return element.classes
        .firstWhere((s) => s.startsWith(prefix), orElse: () => '');
  }

  set iconName(String name) {
    element.classes.removeWhere((s) => s.startsWith(prefix));
    element.classes.add('$prefix$name');
  }

  static bool elementIsOcticon(Element el) =>
      el.classes.any((s) => s.startsWith(prefix));
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
    _messageContainer = DElement(div.querySelector('.message-container'));

    final closeLink = DElement(div.querySelector('.flash-close'));
    closeLink.onClick.listen((event) {
      hide();
    });
  }

  static const classNamesForStyles = <FlashBoxStyle, String>{
    FlashBoxStyle.warn: 'flash-warn',
    FlashBoxStyle.error: 'flash-error',
    FlashBoxStyle.success: 'flash-success',
  };

  DElement _element;

  DElement _messageContainer;

  void showStrings(List<String> messages, [FlashBoxStyle style]) {
    showElements(messages.map((m) => DivElement()..text = m).toList(), style);
  }

  void showElements(List<Element> elements, [FlashBoxStyle style]) {
    _element.clearAttr('hidden');
    _element.element.classes
        .removeWhere((s) => classNamesForStyles.values.contains(s));

    if (style != null) {
      _element.toggleClass(classNamesForStyles[style], true);
    }

    _messageContainer.clearChildren();

    for (final element in elements) {
      _messageContainer.add(element);
    }
  }

  void hide() {
    _element.setAttr('hidden');
  }
}

class NewEmbedContext {
  final Editor userCodeEditor;
  final Editor testEditor;

  Document _dartDoc;

  String get testMethod => testEditor.document.value;

  set testMethod(String value) {
    testEditor.document.value = value;
  }

  final _dartDirtyController = StreamController.broadcast();

  final _dartReconcileController = StreamController.broadcast();

  NewEmbedContext(this.userCodeEditor, this.testEditor) {
    _dartDoc = userCodeEditor.document;
    _dartDoc.onChange.listen((_) => _dartDirtyController.add(null));
    _createReconciler(_dartDoc, _dartReconcileController, 1250);
  }

  Document get dartDocument => _dartDoc;

  String get dartSource => _dartDoc.value;

  set dartSource(String value) {
    userCodeEditor.document.value = value;
  }

  String get activeMode => userCodeEditor.mode;

  Stream get onDartDirty => _dartDirtyController.stream;

  Stream get onDartReconcile => _dartReconcileController.stream;

  void markDartClean() => _dartDoc.markClean();

  /// Restore the focus to the last focused editor.
  void focus() => userCodeEditor.focus();

  void _createReconciler(Document doc, StreamController controller, int delay) {
    Timer timer;
    doc.onChange.listen((_) {
      if (timer != null) timer.cancel();
      timer = Timer(Duration(milliseconds: delay), () {
        controller.add(null);
      });
    });
  }

  /// Return true if the current cursor position is in a whitespace char.
  bool cursorPositionIsWhitespace() {
    // TODO(DomesticMouse): implement with CodeMirror integration
    return false;
  }
}
