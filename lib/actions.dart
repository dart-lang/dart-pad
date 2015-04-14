// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.actions;

import 'dart:html';

import 'elements/elements.dart';
import 'sharing/gists.dart';
import 'sharing/mutable_gist.dart';

/// An action that creates a new pad when clicked.
class NewPadAction {
  final DButton _button;
  final MutableGist _gist;
  final GistController _gistController;

  NewPadAction(Element element, this._gist, this._gistController) :
      _button = new DButton(element) {
    _button.onClick.listen((e) => _handleButtonPress());
  }

  void _handleButtonPress() {
    if (_gist.dirty) {
      if (!window.confirm('Discard changes to the current pad?')) return;
    }

    _gistController.createNewGist();
  }
}
