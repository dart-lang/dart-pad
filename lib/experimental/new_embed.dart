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
  DivElement testCodeButton;
  DivElement runCodeButton;
  TextAreaElement editorTextArea;

  TabController tabController;
  EditorTabView editorTabView;
  TestTabView testTabView;
  ConsoleTabView consoleTabView;

  ExecutionService executionSvc;

  NewEmbedContext context;

  NewEmbed() {
    tabController = TabController();
    for (String name in ['editor', 'test', 'console']) {
      tabController.registerTab(
          TabElement(querySelector('#${name}-tab'), name: name, onSelect: () {
        editorTabView.setSelected(name == 'editor');
        testTabView.setSelected(name == 'test');
        consoleTabView.setSelected(name == 'console');
      }));
    }

    testCodeButton = querySelector('#test-code');
    runCodeButton = querySelector('#run-code');

    editorTextArea = querySelector('#editor');
    editorTabView = EditorTabView(DElement(editorTextArea));
    consoleTabView = ConsoleTabView(DElement(querySelector('#console-view')));
    testTabView = TestTabView(DElement(querySelector('#test-view')));

    // These two will ultimately be loaded from GitHub.
    testTabView.setTestCode(testMain);
    editorTextArea.value = initialCode;

    executionSvc = ExecutionServiceIFrame(querySelector('#frame'));
    executionSvc.onStderr.listen((err) => consoleTabView.appendError(err));
    executionSvc.onStdout.listen((msg) => consoleTabView.appendMessage(msg));
    executionSvc.testResults.listen((result) {
      consoleTabView.appendMessage(result.message);
      if (result.success) {
        _disableTestButton();
      }
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
        NewEmbedEditorFactory().createFromElement(editorTextArea));

    testCodeButton.addEventListener('click', (e) => _handleRun());
  }

  // TODO(RedBrogdon): Remove when gist-loading is integrated.
  final testMain = '''
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

  void _handleRun() {
    final fullCode =
        '${context.dartSource}\n$testMain\n${executionSvc.testResultDecoration}';
    var input = CompileRequest()..source = fullCode;
    deps[DartservicesApi]
        .compile(input)
        .timeout(longServiceCallTimeout)
        .then((CompileResponse response) {
      executionSvc.execute('', '', response.result);
    }).catchError((e) {
      // TODO(RedBrogdon): Implement error handling / reporting
      print(e);
    }).whenComplete(() {
      // TODO(RedBrogdon): Implement compilation completion UI
    });
  }

  void _disableTestButton() {
    testCodeButton.style.display = 'none';
  }
}

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
  const TestTabView(DElement element) : super(element);

  void setTestCode(String code) {
    element.clearChildren();
    element.add(PreElement()..text = code);
  }
}

class NewEmbedContext {
  final NewEmbedEditor editor;

  Document _dartDoc;

  final _dartDirtyController = StreamController.broadcast();

  final _dartReconcileController = StreamController.broadcast();

  NewEmbedContext(this.editor) {
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
