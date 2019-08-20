// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library new_playground;

import 'dart:html';

import 'package:mdc_web/mdc_web.dart';

import '../elements/elements.dart';

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

  Playground() {
    _initializeButtons();
    _registerMDCButtons();
  }

  void _initializeButtons() {
    newButton = DButton(querySelector('#new-button'));
    resetButton = DButton(querySelector('#reset-button'));
    formatButton = DButton(querySelector('#format-button'));
    shareButton = DButton(querySelector('#share-button'));
    samplesButton = DButton(querySelector('#samples-dropdown-button'));
    runButton = DButton(querySelector('#run-button'))..onClick.listen((e) {
      _handleRun();
    });

  }

  /// Adds a material ripple effect
  void _registerMDCButtons() {
    MDCRipple(newButton.element);
    MDCRipple(resetButton.element);
    MDCRipple(formatButton.element);
    MDCRipple(shareButton.element);
    MDCRipple(samplesButton.element);
    MDCRipple(runButton.element);
  }

  void _handleRun() async {
    print('Run');
  }

}
