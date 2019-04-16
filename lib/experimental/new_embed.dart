// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Document;

import 'package:dart_pad/sharing/gists.dart';

import '../completion.dart';
import '../core/dependencies.dart';
import '../core/modules.dart';
import '../dart_pad.dart';
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
  DisableableButton executeButton;
  DisableableButton reloadGistButton;
  DisableableButton formatButton;
  DisableableButton showHintButton;

  DElement navBarElement;
  TabController tabController;
  TabView editorTabView;
  TabView testTabView;
  ConsoleTabView consoleTabView;

  Counter unreadConsoleCounter;

  FlashBox testResultBox;
  FlashBox analysisResultBox;
  FlashBox hintBox;

  ExecutionService executionSvc;

  EditorFactory editorFactory = codeMirrorFactory;

  Editor userCodeEditor;
  Editor testEditor;

  NewEmbedContext context;

  final DelayedTimer _debounceTimer = DelayedTimer(
    minDelay: Duration(milliseconds: 1000),
    maxDelay: Duration(milliseconds: 5000),
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

    navBarElement = DElement(querySelector('#navbar'));

    unreadConsoleCounter = Counter(querySelector('#unread-console-counter'));

    executeButton =
        DisableableButton(querySelector('#execute'), _handleExecute);

    reloadGistButton = DisableableButton(querySelector('#reload-gist'), () {
      if (gistId.isNotEmpty) {
        _loadAndShowGist(gistId);
      }
    });

    reloadGistButton.disabled = gistId.isEmpty;

    showHintButton = DisableableButton(querySelector('#show-hint'), () {
      hintBox.showStrings([context.hint]);
    });

    formatButton = DisableableButton(
      querySelector('#format-code'),
      _performFormat,
    );

    testResultBox = FlashBox(querySelector('#test-result-box'));
    analysisResultBox = FlashBox(querySelector('#analysis-result-box'));
    hintBox = FlashBox(querySelector('#hint-box'));

    userCodeEditor =
        editorFactory.createFromElement(querySelector('#user-code-editor'))
          ..theme = 'elegant'
          ..mode = 'dart'
          ..showLineNumbers = true;
    userCodeEditor.document.onChange.listen(_performAnalysis);

    testEditor = editorFactory.createFromElement(querySelector('#test-editor'))
      ..theme = 'elegant'
      ..mode = 'dart'
      // TODO(devoncarew): We should make this read-only after initial beta
      // testing.
      //..readOnly = true
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

    editorFactory.registerCompleter(
        'dart', DartCompleter(dartServices, userCodeEditor.document));
    keys.bind(['ctrl-space', 'macctrl-space'], () {
      if (userCodeEditor.hasFocus) {
        userCodeEditor.showCompletions();
      }
    }, 'Completion');
    document.onKeyUp.listen(_handleAutoCompletion);

    if (supportsFlutterWeb) {
      // Make the web output area visible.
      querySelector('#web-output').removeAttribute('hidden');

      // Shrink the code editing area.
      querySelector('#user-code-editor').classes.add('web-output-showing');
    }

    if (gistId.isNotEmpty) {
      _loadAndShowGist(gistId, analyze: false);
    }
  }

  /// Toggles the state of several UI components based on whether the editor is
  /// too busy to handle code changes, execute/reset requests, etc.
  set editorIsBusy(bool value) {
    navBarElement.toggleClass('busy', value);
    userCodeEditor.readOnly = value;
    executeButton.disabled = value;
    formatButton.disabled = value;
    reloadGistButton.disabled = value || gistId.isEmpty;
    showHintButton.disabled = value || context.hint.isEmpty;
  }

  Future<void> _loadAndShowGist(String id, {bool analyze = true}) async {
    editorIsBusy = true;
    final GistLoader loader = deps[GistLoader];
    final gist = await loader.loadGist(id);
    context.dartSource = gist.getFile('main.dart')?.content ?? '';
    context.testMethod = gist.getFile('test.dart')?.content ?? '';
    context.hint = gist.getFile('hint.txt')?.content ?? '';
    editorIsBusy = false;

    if (analyze) {
      _performAnalysis();
    }
  }

  void _handleExecute() {
    editorIsBusy = true;
    analysisResultBox.hide();
    testResultBox.hide();
    hintBox.hide();
    consoleTabView.clear();

    final fullCode = '${context.dartSource}\n${context.testMethod}\n'
        '${executionSvc.testResultDecoration}';

    var input = CompileRequest()..source = fullCode;

    if (supportsFlutterWeb) {
      dartServices
          .compileDDC(input)
          .timeout(longServiceCallTimeout)
          .then((CompileDDCResponse response) {
        executionSvc.execute(
          '',
          '',
          response.result,
          modulesBaseUrl: response.modulesBaseUrl,
        );
      }).catchError((e, st) {
        consoleTabView.appendError('Error compiling to JavaScript:\n$e');
        print(st);
        tabController.selectTab('console');
      }).whenComplete(() {
        editorIsBusy = false;
      });
    } else {
      dartServices
          .compile(input)
          .timeout(longServiceCallTimeout)
          .then((CompileResponse response) {
        executionSvc.execute('', '', response.result);
      }).catchError((e, st) {
        consoleTabView.appendError('Error compiling to JavaScript:\n$e');
        print(st);
        tabController.selectTab('console');
      }).whenComplete(() {
        editorIsBusy = false;
      });
    }
  }

  void _displayIssues(List<AnalysisIssue> issues) {
    analysisResultBox.hide();
    testResultBox.hide();
    hintBox.hide();

    if (issues.isEmpty) {
      return;
    }

    List<String> messages = issues.map((AnalysisIssue issue) {
      String message = issue.message;
      if (message.endsWith('.')) {
        message = message.substring(0, message.length - 1);
      }
      return '$message - line ${issue.line}';
    }).toList();

    analysisResultBox.showStrings(messages, FlashBoxStyle.warn);
  }

  /// Perform static analysis of the source code.
  void _performAnalysis([_]) {
    _debounceTimer.invoke(() {
      final dartServices = deps[DartservicesApi] as DartservicesApi;
      final userSource = context.dartSource;
      // Create a synthesis of the user code and other code to analyze.
      final fullSource = '$userSource\n'
          '${context.testMethod}\n'
          '${executionSvc.testResultDecoration}\n';
      final sourceRequest = SourceRequest()..source = fullSource;
      final lines = Lines(sourceRequest.source);

      dartServices
          .analyze(sourceRequest)
          .timeout(serviceCallTimeout)
          .then((AnalysisResults result) {
        // Discard if the document has been mutated since we requested analysis.
        if (userSource != context.dartSource) return;

        _displayIssues(result.issues);

        Iterable<Annotation> issues = result.issues.map((AnalysisIssue issue) {
          final charStart = issue.charStart;
          final startLine = lines.getLineForOffset(charStart);
          final endLine = lines.getLineForOffset(charStart + issue.charLength);

          return Annotation(
            issue.kind,
            issue.message,
            issue.line,
            start: Position(
              startLine,
              charStart - lines.offsetForLine(startLine),
            ),
            end: Position(
              endLine,
              charStart + issue.charLength - lines.offsetForLine(startLine),
            ),
          );
        });

        userCodeEditor.document.setAnnotations(issues.toList());
      }).catchError((e) {
        if (e is! TimeoutException) {
          final String message = e is ApiRequestError ? e.message : '$e';

          _displayIssues([
            AnalysisIssue()
              ..kind = 'error'
              ..line = 1
              ..message = message
          ]);
          userCodeEditor.document.setAnnotations([]);
        }
      });
    });
  }

  void _performFormat() async {
    String originalSource = userCodeEditor.document.value;
    SourceRequest input = SourceRequest()..source = originalSource;

    try {
      formatButton.disabled = true;
      FormatResponse result =
          await dartServices.format(input).timeout(serviceCallTimeout);

      formatButton.disabled = false;

      // Check that the user hasn't edited the source since the format request.
      if (originalSource == userCodeEditor.document.value) {
        // And, check that the format request did modify the source code.
        if (originalSource != result.newString) {
          userCodeEditor.document.updateValue(result.newString);
          _performAnalysis();
        }
      }
    } catch (e) {
      formatButton.disabled = false;
      print(e);
    }
  }

  void _handleAutoCompletion(KeyboardEvent e) {
    if (userCodeEditor.hasFocus && e.keyCode == KeyCode.PERIOD) {
      userCodeEditor.showCompletions(autoInvoked: true);
    }
  }

  bool get supportsFlutterWeb {
    Uri url = Uri.parse(window.location.toString());
    return url.queryParameters['fw'] == 'true';
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
    element.text = '$_itemCount';
    element.attributes.remove('hidden');
  }

  void clear() {
    _itemCount = 0;
    element.setAttribute('hidden', 'true');
  }
}

/// It's a real word, I swear.
class DisableableButton {
  DisableableButton(ButtonElement anchorElement, VoidCallback onClick)
      : assert(anchorElement != null),
        assert(onClick != null) {
    _element = DElement(anchorElement);
    _element.onClick.listen((e) => onClick());
  }

  static const disabledClassName = 'disabled';

  DElement _element;

  set disabled(bool value) => _element.toggleClass(disabledClassName, value);
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

  String hint = '';

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
