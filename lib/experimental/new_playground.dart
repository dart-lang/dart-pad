// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library new_playground;

import 'dart:html';

import 'package:mdc_web/mdc_web.dart';
import 'package:split/split.dart';

import '../core/modules.dart';
import '../elements/elements.dart';
import '../modules/codemirror_module.dart';
import '../modules/dart_pad_module.dart';
import '../modules/dartservices_module.dart';

Playground _playground;

void init() {
  _playground = Playground();
}

class Playground {
  DButton newButton;
  DButton resetButton;
  DButton formatButton;
  DButton shareButton;
  DButton samplesButton;
  DButton runButton;

  Splitter splitter;

  Playground() {
    _initButtons();
    _registerMDCButtons();
    _initSplitters();
    _initModules().then((_) {
      _initPlayground();
    });
  }

  void _initButtons() {
    newButton = DButton(querySelector('#new-button'));
    resetButton = DButton(querySelector('#reset-button'));
    formatButton = DButton(querySelector('#format-button'));
    shareButton = DButton(querySelector('#share-button'));
    samplesButton = DButton(querySelector('#samples-dropdown-button'));
    runButton = DButton(querySelector('#run-button'))
      ..onClick.listen((e) {
        _handleRun();
      });
  }

  /// Adds a material ripple effect to the material buttons
  void _registerMDCButtons() {
    MDCRipple(newButton.element);
    MDCRipple(resetButton.element);
    MDCRipple(formatButton.element);
    MDCRipple(shareButton.element);
    MDCRipple(samplesButton.element);
    MDCRipple(runButton.element);
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

  Future _initModules() async {
    ModuleManager modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());
    modules.register(DartSupportServicesModule());
    modules.register(CodeMirrorModule());
  }

  void _initPlayground() {}

  void _handleRun() async {
    print('Run');
  }
}
