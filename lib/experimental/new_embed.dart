// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html' hide Document;

import 'package:dart_pad/editing/editor.dart';
import 'package:dart_pad/elements/elements.dart';
import 'package:dart_pad/experimental/new_embed_editor.dart';
import 'package:dart_pad/modules/dartservices_module.dart';
import 'package:http/http.dart' as http;
import 'package:dart_pad/core/modules.dart';

import '../services/execution_iframe.dart';

NewEmbed get newEmbed => _newEmbed;

NewEmbed _newEmbed;

void init() {
  _newEmbed = NewEmbed();
}

final urlStr =
    'https://dart-services.appspot.com/api/dartservices/v1/compile?alt=json';

final String mainMethod = '''
void main() {
  if (addNumbers(2, 3) == 5) {
    print('TEST SUCCESS');
  } else {
    print('TEST FAILURE');
  } 
}
''';

/// An embeddable DartPad UI that provides the ability to test the user's code
/// snippet against a desired result.
class NewEmbed {
  LinkElement editorTabLink;
  LinkElement testTabLink;
  LinkElement consoleTabLink;
  LinkElement testCodeLink;
  LinkElement runCodeLink;

  DivElement editorTab;
  TextAreaElement editorTextArea;

  DivElement testTab;
  DivElement testView;

  DivElement consoleTab;
  DivElement consoleView;

  ExecutionService executionSvc;
  TabController tabController;

  NewEmbedContext _context;

  NewEmbed() {
    tabController = TabController();
    for (String name in ['dart', 'html', 'css']) {
      tabController.registerTab(
          TabElement(querySelector('#${name}tab'), name: name, onSelect: () {
        Element issuesElement = querySelector('#issues');
        issuesElement.style.display = name == 'dart' ? 'block' : 'none';
        _context.switchTo(name);
      }));
    }

    testCodeLink = querySelector('#test-code');
    runCodeLink = querySelector('#run-code');
    editorTab = querySelector('#editor-tab');
    editorTabLink = querySelector('#editor-tab a');
    editorTextArea = querySelector('#editor');
    testTab = querySelector('#test-tab');
    testTabLink = querySelector('#test-tab a');
    testView = querySelector('#test-view');
    consoleTab = querySelector('#console-tab');
    consoleTabLink = querySelector('#console-tab a');
    consoleView = querySelector('#console-view');
    executionSvc = ExecutionServiceIFrame(querySelector('#frame'));

    editorTabLink.addEventListener('click', (e) {
      editorTab.classes.add('tab-active');
      editorTextArea.classes.remove('tabview-hidden');
      testTab.classes.remove('tab-active');
      testView.classes.add('tabview-hidden');
      consoleTab.classes.remove('tab-active');
      consoleView.classes.add('tabview-hidden');
    });

    editorTabLink.addEventListener('click', (e) {
      editorTab.classes.add('tab-active');
      editorTextArea.classes.remove('tabview-hidden');
      testTab.classes.remove('tab-active');
      testView.classes.add('tabview-hidden');
      consoleTab.classes.remove('tab-active');
      consoleView.classes.add('tabview-hidden');
    });

    editorTabLink.addEventListener('click', (e) {
      editorTab.classes.add('tab-active');
      editorTextArea.classes.remove('tabview-hidden');
      testTab.classes.remove('tab-active');
      testView.classes.add('tabview-hidden');
      consoleTab.classes.remove('tab-active');
      consoleView.classes.add('tabview-hidden');
    });

    executionSvc.onStderr.listen((msg) {
      consoleView.text += 'ERROR: $msg\n';
    });

    executionSvc.onStdout.listen((msg) {
      consoleView.text += '$msg\n';
    });

    testCodeLink.addEventListener('click', (e) async {
      final code = _context.dartSource;
      final markedUpCode = '$code\n$mainMethod';
      final response =
          await http.post(urlStr, body: json.encode({'source': markedUpCode}));
      final compilationResult = json.decode(response.body);
      await executionSvc.execute('', '', compilationResult['result']);
    });

    //_initModules();
    //_initNewEmbed();
  }

  Future _initModules() {
    ModuleManager modules = ModuleManager();

    modules.register(DartServicesModule());

    return modules.start();
  }

  void _initNewEmbed() {
    _context = NewEmbedContext(
        NewEmbedEditorFactory().createFromElement(editorTextArea));
  }
}

class NewEmbedContext {
  final NewEmbedEditor editor;

  Document _dartDoc;

  final _dartDirtyController = StreamController.broadcast();

  final _dartReconcileController = StreamController.broadcast();

  NewEmbedContext(this.editor) {
    editor.mode = 'dart';

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

  //Stream<String> get onModeChange => _modeController.stream;

  void switchTo(String name) {
    String oldMode = activeMode;

    if (name == 'dart') {
      editor.swapDocument(_dartDoc);
    }

    editor.focus();
  }

  String get focusedEditor {
    return 'dart';
  }

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
    return false;
  }
}
