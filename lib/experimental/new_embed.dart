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
  TestResultLabel testResultLabel;

  TabController tabController;
  TabView editorTabView;
  TabView testTabView;
  ConsoleTabView consoleTabView;

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
          }

          if (name == 'test') {
            testEditor.resize();
            testEditor.focus();
          }
        }),
      );
    }

    testResultLabel = TestResultLabel(querySelector('#test-result'));
    executeButton =
        ExecuteCodeButton(querySelector('#execute'), _handleExecute);

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

    editorTabView = TabView(
      DElement(querySelector('#user-code-view')));

    testTabView = TabView(
      DElement(querySelector('#test-view')));

    consoleTabView = ConsoleTabView(DElement(querySelector('#console-view')));

    executionSvc = ExecutionServiceIFrame(querySelector('#frame'));
    executionSvc.onStderr.listen((err) => consoleTabView.appendError(err));
    executionSvc.onStdout.listen((msg) => consoleTabView.appendMessage(msg));
    executionSvc.testResults.listen((result) {
      testResultLabel.setResult(result);
    });

    _initModules().then((_) => _initNewEmbed());
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

    Uri url = Uri.parse(window.location.toString());

    if (url.hasQuery &&
        url.queryParameters['id'] != null &&
        isLegalGistId(url.queryParameters['id'])) {
      _loadAndShowGist(url.queryParameters['id']);
    }
  }

  Future<void> _loadAndShowGist(String id) async {
    final GistLoader loader = deps[GistLoader];
    final gist = await loader.loadGist(id);
    context.dartSource = gist.getFile('main.dart')?.content ?? '';
    context.testMethod = gist.getFile('test.dart')?.content ?? '';
  }

  void _handleExecute() {
    executeButton.ready = false;
    final fullCode =
        '${context.dartSource}\n${context.testMethod}\n${executionSvc.testResultDecoration}';
    var input = CompileRequest()..source = fullCode;
    deps[DartservicesApi]
        .compile(input)
        .timeout(longServiceCallTimeout)
        .then((CompileResponse response) {
          executionSvc.execute('', '', response.result);
        })
        // TODO(redbrogdon): Add logging and possibly output to UI.
        .catchError(print)
        .whenComplete(() {
          executeButton.ready = true;
        });
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
    final line = DivElement()
      ..text = msg
      ..classes.add('console-message');
    element.add(line);
  }

  void appendError(String err) {
    final line = DivElement()
      ..text = err
      ..classes.add('console-error');
    element.add(line);
  }
}

/// A line of text next to the [ExecuteButton] that reports test result messages
/// in red or green.
class TestResultLabel {
  TestResultLabel(this.element);

  final DivElement element;

  void setResult(TestResult result) {
    if (result.messages.isEmpty) {
      element.text = result.success ? 'Test passed!' : 'Test failed.';
    } else {
      element.text = result.messages.first;
    }

    if (result.success) {
      element.classes.add('text-green');
      element.classes.remove('text-red');
    } else {
      element.classes.remove('text-green');
      element.classes.add('text-red');
    }
  }
}

class ExecuteCodeButton {
  /// This constructor will throw if the provided element has no child with a
  /// CSS class that begins with "octicon-".
  ExecuteCodeButton(AnchorElement anchorElement, VoidCallback onClick)
      : assert(anchorElement != null),
        assert(onClick != null) {
    final iconElement =
        anchorElement.children.firstWhere(Octicon.elementIsOcticon);
    _icon = Octicon(iconElement);
    _element = DElement(anchorElement);
    _element.onClick.listen((e) => onClick());
  }

  static const readyIconName = 'triangle-right';
  static const waitingIconName = 'sync';
  static const disabledClassName = 'disabled';

  DElement _element;

  Octicon _icon;

  // Both the icon and the disabled attribute are set at the same time, so
  // checking one should be as good as checking both.
  bool get ready => !_element.hasClass(disabledClassName);

  set ready(bool value) {
    _element.toggleClass(disabledClassName, !value);
    _icon.iconName = value ? readyIconName : waitingIconName;
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
