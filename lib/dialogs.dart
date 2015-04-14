// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.dialogs;

import 'dart:html';

import 'elements/elements.dart';
import 'sharing/gists.dart';
import 'sharing/mutable_gist.dart';

class SharingDialog extends DDialog {
  final GistContainer gistContainer;
  final GistController gistController;

  ParagraphElement _text;
  DButton _cancelButton;
  DButton _shareButton;
  DButton _closeButton;
  DElement _div;
  DInput _padUrl;
  DInput _gistUrl;

  SharingDialog(this.gistContainer, this.gistController) : super(title: 'Sharing') {
    element.classes.toggle('sharing-dialog', true);

    _text = content.add(new ParagraphElement());

    // About to share.
    _cancelButton = new DButton.button(text: 'Cancel');
    _cancelButton.onClick.listen((_) => hide());
    _shareButton = new DButton.button(text: 'Share it!', classes: 'default');
    _shareButton.onClick.listen((_) => _performShare());

    // Already sharing.
    _closeButton = new DButton.button(text: 'Close', classes: 'default');
    _closeButton.onClick.listen((_) => hide());
    _div = new DElement.tag('div')..layoutVertical();

    DElement div = _div.add(new DElement.tag('div', classes: 'row')..layoutHorizontal());
    div.add(new DElement.tag('span', classes: 'sharinglabel'))..text = 'DartPad:';
    DElement inputGroup = div.add(new DElement.tag('div'))
        ..layoutHorizontal()..flex();
    _padUrl = inputGroup.add(new DInput.input(type: 'text'))..flex()..readonly();
    _padUrl.onClick.listen((_) => _padUrl.selectAll());

    div = _div.add(new DElement.tag('div', classes: 'row')..layoutHorizontal());
    div.add(new DElement.tag('span', classes: 'sharinglabel'))..text = 'gist.github.com:';
    inputGroup = div.add(new DElement.tag('div'))..layoutHorizontal()..flex();
    _gistUrl = inputGroup.add(new DInput.input(type: 'text'))..flex()..readonly();
    _gistUrl.onClick.listen((_) => _gistUrl.selectAll());
  }

  void show() {
    _configure(gistContainer.mutableGist);
    super.show();
  }

  void _configure(MutableGist gist) {
    if (!gist.hasId || gist.dirty) {
      _switchTo(aboutToShare: true);
    } else {
      _switchTo(aboutToShare: false);
    }
  }

  void _switchTo({bool aboutToShare: true}) {
    buttonArea.element.children.clear();
    _div.dispose();

    if (aboutToShare) {
      // Show 'about to share'.
      _text.text = 'Sharing this pad will create a permanent, publicly visible '
          'copy on gist.github.com.';

      buttonArea.add(_cancelButton);
      buttonArea.add(new SpanElement()..attributes['flex'] = '');
      buttonArea.add(_shareButton);
    } else {
      // Show the existing sharing info.
      _text.text = 'Share the DartPad link or view the source at gist.github.com.';

      MutableGist gist = gistContainer.mutableGist;

      content.add(_div);
      _padUrl.value = gist.html_url;
      _gistUrl.value = 'https://dartpad.dartlang.org/${gist.id}';

      buttonArea.add(new SpanElement()..attributes['flex'] = '');
      buttonArea.add(_closeButton);
    }
  }

  void _performShare() {
    _shareButton.disabled = true;

    // TODO: Show a spinner.
    gistController.shareAnon().then((_) {
      _switchTo(aboutToShare: false);
    }).whenComplete(() {
      _shareButton.disabled = false;
    });
  }
}
