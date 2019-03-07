// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Document;

import '../core/dependencies.dart';
import '../core/modules.dart';
import '../editing/editor.dart';
import '../elements/elements.dart';
import '../experimental/new_embed_editor.dart';
import '../modules/dart_pad_module.dart';
import '../modules/dartservices_module.dart';
import '../services/common.dart';
import '../services/dartservices.dart';
import '../services/execution_iframe.dart';

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
  EditorTabView editorTabView;
  TextAreaElement editorTextArea;
  TestTabView testTabView;
  ConsoleTabView consoleTabView;

  ExecutionService executionSvc;

  NewEmbedContext context;

  NewEmbed() {
    tabController = NewEmbedTabController();
    for (String name in ['editor', 'test', 'console']) {
      tabController.registerTab(
          TabElement(querySelector('#$name-tab'), name: name, onSelect: () {
        editorTabView.setSelected(name == 'editor');
        testTabView.setSelected(name == 'test');
        consoleTabView.setSelected(name == 'console');
      }));
    }

    testResultLabel = TestResultLabel(querySelector('#test-result'));
    executeButton =
        ExecuteCodeButton(querySelector('#execute'), _handleExecute);

    editorTextArea = querySelector('#editor');
    editorTabView = EditorTabView(DElement(editorTextArea));
    consoleTabView = ConsoleTabView(DElement(querySelector('#console-view')));

    // Right now the entire tab view is just the textarea, but that will not be
    // the case going forward, hence the separate parameters.
    testTabView = TestTabView(
      DElement(querySelector('#test-view')),
      querySelector('#test-view'),
    );

    // These two will ultimately be loaded from GitHub.
    testTabView.testMethod = initialTest;
    editorTextArea.value = initialCode;

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
    context = NewEmbedContext(
        NewEmbedEditorFactory().createFromElement(editorTextArea), testTabView);
  }

  // TODO(RedBrogdon): Remove when gist-loading is integrated.
  final initialTest = '''
void main() {
  final str = stringify(2, 3); 
  if (str == '2 3') {
    _result(true, 'Test passed. Great job!');
  } else if (str == '23') {
    _result(false, 'Test failed. It looks like you forgot the space!');
  } else if (str == null) {
    _result(false, 'Test failed. Did you forget to return a value?');
  } else {
    _result(false, 'That\\'s not quite right. Keep trying!');
  }
}
''';

  // TODO(RedBrogdon): Remove when gist-loading is integrated.
  final initialCode = '''
String stringify(int x, int y) {
  // Return a formatted string here
}
''';

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
abstract class TabView {
  final DElement element;

  const TabView(this.element);

  void setSelected(bool selected) {
    if (selected) {
      element.setAttr('selected');
    } else {
      element.clearAttr('selected');
    }
  }
}

class EditorTabView extends TabView {
  const EditorTabView(DElement element) : super(element);
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

class TestTabView extends TabView {
  final TextAreaElement testEditor;

  const TestTabView(DElement element, this.testEditor) : super(element);

  String get testMethod => testEditor.value;

  set testMethod(String v) {
    testEditor.value = v;
  }
}

/// A line of text next to the [ExecuteButton] that reports test result messages
/// in red or green.
class TestResultLabel {
  TestResultLabel(this.element);

  final DivElement element;

  void setResult(TestResult result) {
    element.text = result.message;

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
  final NewEmbedEditor editor;
  final TestTabView testView;

  Document _dartDoc;

  String get testMethod => testView.testMethod;

  final _dartDirtyController = StreamController.broadcast();

  final _dartReconcileController = StreamController.broadcast();

  NewEmbedContext(this.editor, this.testView) {
    _dartDoc = editor.document;
    _dartDoc.onChange.listen((_) => _dartDirtyController.add(null));
    _createReconciler(_dartDoc, _dartReconcileController, 1250);
  }

  Document get dartDocument => _dartDoc;

  String get dartSource => _dartDoc.value;

  set dartSource(String value) {
    _dartDoc.value = value;
  }

  String get activeMode => editor.mode;

  Stream get onDartDirty => _dartDirtyController.stream;

  Stream get onDartReconcile => _dartReconcileController.stream;

  void markDartClean() => _dartDoc.markClean();

  /// Restore the focus to the last focused editor.
  void focus() => editor.focus();

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
