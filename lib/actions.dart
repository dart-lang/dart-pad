// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.actions;

import 'dart:html';

import 'dart_pad.dart';
import 'elements/elements.dart';
import 'sharing/gists.dart';
import 'sharing/mutable_gist.dart';

/// An action that creates a new pad when clicked.
class NewPadAction {
  final DButton _button;
  final MutableGist _gist;
  final GistStorage _gistStorage;

  NewPadAction(Element element, this._gist, this._gistStorage) :
      _button = new DButton(element) {
    _button.onClick.listen((e) => _handleButtonPress());
  }

  void _handleButtonPress() {
    if (_gist.dirty) {
      if (!window.confirm('Discard changes to the current pad?')) return;
    }

    _gistStorage.clearStoredGist();

    if (ga != null) ga.sendEvent('main', 'new');

    DToast.showMessage('New pad created');
    router.go('gist', {'gist': ''});
  }
}

/// An action that creates a new anonymous copy of the current pad.
class SharePadAction {
  final DButton _button;
  final GistContainer _gistContainer;

  SharePadAction(Element element, this._gistContainer) :
      _button = new DButton(element) {
    _button.onClick.listen((e) => _handleButtonPress());
    _gist.onDirtyChanged.listen((dirty) => _button.disabled = !dirty);
  }

  MutableGist get _gist => _gistContainer.mutableGist;

  void _handleButtonPress() {
    final String message = 'Sharing this pad will create a permanent, publicly '
        'visible copy on gist.github.com.';

    if (!window.confirm(message)) return;

    if (ga != null) ga.sendEvent('main', 'share');

    gistLoader.createAnon(_gist.createGist()).then((Gist newGist) {
      _gistContainer.overrideNextRoute(newGist);
      router.go('gist', {'gist': newGist.id});
      DToast.showMessage('Created ${newGist.id}');
    }).catchError((e) {
      String message = 'Error saving gist: ${e}';
      DToast.showMessage(message);
      ga.sendException('GistLoader.createAnon: failed to create gist');
    });
  }
}
