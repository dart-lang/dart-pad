// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library new_playground;

import 'dart:async';
import 'dart:html';

import 'package:mdc_web/mdc_web.dart';
import 'package:split/split.dart';

import 'context.dart';
import 'core/dependencies.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'editing/editor.dart';
import 'elements/elements.dart';
import 'modules/codemirror_module.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'playground_context.dart';
import 'services/common.dart';
import 'services/dartservices.dart';
import 'services/execution_iframe.dart';
import 'src/ga.dart';

Playground _playground;

void init() {
  _playground = Playground();
}

class Playground {
  MDCButton newButton;
  MDCButton resetButton;
  MDCButton formatButton;
  MDCButton shareButton;
  MDCButton samplesButton;
  MDCButton runButton;

  Splitter splitter;

  Editor editor;
  PlaygroundContext _context;
  Layout _layout;

  Playground() {
    _initButtons();
    _initSplitters();
    _initCheckboxes();
    _initModules().then((_) {
      _initPlayground();
    });
  }

  DivElement get _editorHost => querySelector('#editor-host');
  DivElement get _outputHost => querySelector('#output-host');
  IFrameElement get _frame => querySelector('#frame');
  InputElement get dartCheckbox => querySelector('#dart-checkbox');
  InputElement get webCheckbox => querySelector('#web-checkbox');
  InputElement get flutterCheckbox => querySelector('#flutter-checkbox');
  Map<InputElement, Layout> get _layouts => {
        flutterCheckbox: Layout.flutter,
        dartCheckbox: Layout.dart,
        webCheckbox: Layout.web,
      };

  void _initButtons() {
    newButton = MDCButton(querySelector('#new-button'));
    resetButton = MDCButton(querySelector('#reset-button'));
    formatButton = MDCButton(querySelector('#format-button'));
    shareButton = MDCButton(querySelector('#share-button'));
    samplesButton = MDCButton(querySelector('#samples-dropdown-button'));
    runButton = MDCButton(querySelector('#run-button'))
      ..onClick.listen((e) {
        _handleRun();
      });
  }

  void _initSplitters() {
    var editorPanel = querySelector('#editor-panel');
    var outputPanel = querySelector('#output-panel');

    splitter = flexSplit(
      [editorPanel, outputPanel],
      horizontal: true,
      gutterSize: 6,
      sizes: [50, 50],
      minSize: [100, 100],
    );
  }

  void _initCheckboxes() {
    _changeLayout(Layout.dart);
    for (var checkbox in _layouts.keys) {
      checkbox.onClick.listen((event) {
        event.preventDefault();
        Timer(Duration(milliseconds: 100), () {
          _changeLayout(_layouts[checkbox]);
        });
      });
    }
  }

  Future _initModules() async {
    ModuleManager modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());
    modules.register(DartSupportServicesModule());
    modules.register(CodeMirrorModule());

    await modules.start();
  }

  void _initPlayground() {
    // Set up the iframe.
    deps[ExecutionService] = ExecutionServiceIFrame(_frame);
    executionService.onStdout.listen(_showOutput);
    executionService.onStderr.listen((m) => _showOutput(m, error: true));

    // Set up Google Analytics.
    deps[Analytics] = Analytics();

    // Set up CodeMirror
    editor = editorFactory.createFromElement(_editorHost)
      ..theme = 'darkpad'
      ..mode = 'dart';

    _context = PlaygroundContext(editor);
    deps[Context] = _context;
  }

  void _handleRun() async {
    ga.sendEvent('main', 'run');
    runButton.disabled = true;

    Stopwatch compilationTimer = Stopwatch()..start();

    final CompileRequest compileRequest = CompileRequest()
      ..source = context.dartSource;

    try {
      final CompileResponse response = await dartServices
          .compile(compileRequest)
          .timeout(longServiceCallTimeout);

      ga.sendTiming(
        'action-perf',
        'compilation-e2e',
        compilationTimer.elapsedMilliseconds,
      );

      _clearOutput();

      return await executionService.execute(
        _context.htmlSource,
        _context.cssSource,
        response.result,
      );
    } catch (e) {
      ga.sendException('${e.runtimeType}');
      final message = (e is DetailedApiRequestError) ? e.message : '$e';
      _showSnackbar('Error compiling to JavaScript');
      _showOutput('Error compiling to JavaScript:\n$message', error: true);
    } finally {
      runButton.disabled = false;
    }
  }

  void _clearOutput() {
    _outputHost.text = '';
  }

  final _bufferedOutput = <SpanElement>[];
  final _outputDuration = Duration(milliseconds: 32);

  void _showOutput(String message, {bool error = false}) {
    SpanElement span = SpanElement()..text = '$message\n';
    span.classes.add(error ? 'errorOutput' : 'normal');
    // Buffer the console output so that heavy writing to stdout does not starve
    // the DOM thread.
    _bufferedOutput.add(span);
    if (_bufferedOutput.length == 1) {
      Timer(_outputDuration, () {
        _outputHost.children.addAll(_bufferedOutput);
        _outputHost.children.last.scrollIntoView(ScrollAlignment.BOTTOM);
        _bufferedOutput.clear();
      });
    }
  }

  void _showSnackbar(String message) {
    var div = querySelector('.mdc-snackbar');
    var snackbar = MDCSnackbar(div)..labelText = message;
    snackbar.open();
  }

  void _changeLayout(Layout layout) {
    _layout = layout;

    for (var checkbox in _layouts.keys) {
      if (_layouts[checkbox] == layout) {
        checkbox.checked = true;
      } else {
        checkbox.checked = false;
      }
    }

    if (layout == Layout.dart) {
      _frame.hidden = true;
    } else if (layout == Layout.flutter) {
      _frame.hidden = false;
    } else if (layout == Layout.web) {
      _frame.hidden = false;
    }
  }
}

/// Adds a ripple effect to material design buttons
class MDCButton extends DButton {
  final MDCRipple ripple;
  MDCButton(ButtonElement element)
      : ripple = MDCRipple(element),
        super(element);
}

enum Layout {
  flutter,
  dart,
  web,
}
