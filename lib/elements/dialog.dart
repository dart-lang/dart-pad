// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:dart_pad/src/util.dart';
import 'package:mdc_web/mdc_web.dart';

enum DialogResult {
  yes,
  no,
  ok,
  cancel,
}

class Dialog {
  final MDCDialog _mdcDialog;
  final Element _leftButton;
  final Element _rightButton;
  final Element _title;
  final Element _content;

  Dialog()
      : assert(querySelector('.mdc-dialog') != null),
        assert(querySelector('#dialog-left-button') != null),
        assert(querySelector('#dialog-right-button') != null),
        assert(querySelector('#my-dialog-title') != null),
        assert(querySelector('#my-dialog-content') != null),
        _mdcDialog = MDCDialog(querySelector('.mdc-dialog')),
        _leftButton = querySelector('#dialog-left-button'),
        _rightButton = querySelector('#dialog-right-button'),
        _title = querySelector('#my-dialog-title'),
        _content = querySelector('#my-dialog-content');

  Future<DialogResult> showYesNo(String title, String htmlMessage,
      {String yesText = 'Yes', String noText = 'No'}) {
    return _setUpAndDisplay(
      title,
      htmlMessage,
      noText,
      yesText,
      DialogResult.no,
      DialogResult.yes,
    );
  }

  Future<DialogResult> showOk(String title, String htmlMessage) {
    return _setUpAndDisplay(
      title,
      htmlMessage,
      '',
      'OK',
      DialogResult.cancel,
      DialogResult.ok,
      false,
    );
  }

  Future<DialogResult> showOkCancel(String title, String htmlMessage) {
    return _setUpAndDisplay(
      title,
      htmlMessage,
      'Cancel',
      'OK',
      DialogResult.cancel,
      DialogResult.ok,
    );
  }

  Future<DialogResult> _setUpAndDisplay(
      String title,
      String htmlMessage,
      String leftButtonText,
      String rightButtonText,
      DialogResult leftButtonResult,
      DialogResult rightButtonResult,
      [bool showLeftButton = true]) {
    _title.text = title;
    _content.setInnerHtml(htmlMessage, validator: PermissiveNodeValidator());
    _rightButton.text = rightButtonText;

    final completer = Completer<DialogResult>();
    StreamSubscription leftSub;

    if (showLeftButton) {
      _leftButton.text = leftButtonText;
      _leftButton.removeAttribute('hidden');
      leftSub = _leftButton.onClick.listen((_) {
        completer.complete(leftButtonResult);
      });
    } else {
      _leftButton.setAttribute('hidden', 'true');
    }

    final rightSub = _rightButton.onClick.listen((_) {
      completer.complete(rightButtonResult);
    });

    _mdcDialog.open();

    return completer.future.then((v) {
      leftSub?.cancel();
      rightSub.cancel();
      _mdcDialog.close();
      return v;
    });
  }
}
