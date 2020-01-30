// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.actions;

import 'dart:html';

import 'dialogs.dart';
import 'elements/elements.dart';
import 'sharing/gists.dart';

/// An action that creates a new pad when clicked.
class NewPadAction {
  final DButton _button;
  final GistController _gistController;

  NewPadAction(ButtonElement element, this._gistController)
      : _button = DButton(element) {
    _button.onClick.listen((e) => _handleButtonPress());
  }

  void _handleButtonPress() {
    OkCancelDialog('Create New Pad', 'Discard changes to the current pad?',
            _gistController.createNewGist,
            okText: 'Discard')
        .show();
  }
}
