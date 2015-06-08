// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.dialogs;

import 'dart:async';
import 'dart:html';

import 'core/keys.dart';
import 'elements/elements.dart';
import 'sharing/gists.dart';
import 'sharing/mutable_gist.dart';
import 'src/util.dart';

/**
 * Show an OK / Cancel dialog, and return the option that the user selected.
 */
Future<bool> confirm(String title, String message,
    {String okText: 'OK', String cancelText: 'Cancel'}) {
  OkCancelDialog dialog = new OkCancelDialog(title, message,
      okText: okText, cancelText: cancelText);
  dialog.show();
  return dialog.future;
}

class OkCancelDialog extends DDialog {
  Completer<bool> _completer = new Completer();

  OkCancelDialog(String title, String message,
      {String okText: 'OK', String cancelText: 'Cancel'})
      : super(title: title) {
    content.add(new ParagraphElement()..text = message);

    DButton cancelButton = buttonArea.add(new DButton.button(text: cancelText));
    buttonArea.add(new SpanElement()..attributes['flex'] = '');
    cancelButton.onClick.listen((_) => hide());

    DButton okButton =
        buttonArea.add(new DButton.button(text: okText, classes: 'default'));
    okButton.onClick.listen((_) {
      _completer.complete(true);
      hide();
    });
  }

  void hide() {
    if (!_completer.isCompleted) _completer.complete(false);

    super.hide();
  }

  Future<bool> get future => _completer.future;
}

class AboutDialog extends DDialog {
  AboutDialog([String version]) : super(title: 'About DartPad') {
    ParagraphElement p = content.add(new ParagraphElement());
    String text = privacyText;
    if (version != null) text += " Based on Dart SDK ${version}.";
    p.setInnerHtml(text, validator: new PermissiveNodeValidator());

    buttonArea.add(new SpanElement()..attributes['flex'] = '');
    DButton okButton =
        buttonArea.add(new DButton.button(text: "OK", classes: 'default'));
    okButton.onClick.listen((_) => hide());
  }
}

class SharingDialog extends DDialog {
  final GistContainer gistContainer;
  final GistController gistController;

  ParagraphElement _text;
  TextAreaElement _textArea;
  DButton _cancelButton;
  DButton _shareButton;
  DButton _closeButton;
  DElement _div;
  DInput _padUrl;
  DInput _gistUrl;
  String _summary;

  SharingDialog(
      GistContainer this.gistContainer, GistController this.gistController,
      {String summary: ""})
      : super(title: 'Sharing') {
    element.classes.toggle('sharing-dialog', true);
    _summary = summary;

    content.setAttr('layout');
    content.setAttr('vertical');

    _text = content.add(new ParagraphElement());
    _textArea = content.add(new TextAreaElement());
    _textArea.className = 'sharingSummaryText';
    _textArea.setAttribute('flex', '');

    // About to share.
    _cancelButton = new DButton.button(text: 'Cancel');
    _cancelButton.onClick.listen((_) => hide());
    _shareButton = new DButton.button(text: 'Share it!', classes: 'default');
    _shareButton.onClick.listen((_) => _performShare());

    // Already sharing.
    _closeButton = new DButton.button(text: 'Close', classes: 'default');
    _closeButton.onClick.listen((_) => hide());
    _div = new DElement.tag('div')..layoutVertical();

    DElement div =
        _div.add(new DElement.tag('div', classes: 'row')..layoutHorizontal());
    div.add(new DElement.tag('span', classes: 'sharinglabel'))
      ..text = 'DartPad:';
    DElement inputGroup = div.add(new DElement.tag('div'))
      ..layoutHorizontal()
      ..flex();
    _padUrl = inputGroup.add(new DInput.input(type: 'text'))
      ..flex()
      ..readonly();
    _padUrl.onClick.listen((_) => _padUrl.selectAll());

    div = _div.add(new DElement.tag('div', classes: 'row')..layoutHorizontal());
    div.add(new DElement.tag('span', classes: 'sharinglabel'))
      ..text = 'gist.github.com:';
    inputGroup = div.add(new DElement.tag('div'))
      ..layoutHorizontal()
      ..flex();
    _gistUrl = inputGroup.add(new DInput.input(type: 'text'))
      ..flex()
      ..readonly();
    _gistUrl.onClick.listen((_) => _gistUrl.selectAll());
  }

  void showWithSummary(String summary) {
    this._summary = summary;
    show();
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
      _textArea.defaultValue = _summary == null ? '' : _summary;
      _textArea.style.display = 'block';

      buttonArea.add(_cancelButton);
      buttonArea.add(new SpanElement()..attributes['flex'] = '');
      buttonArea.add(_shareButton);
    } else {
      // Show the existing sharing info.
      _text.text =
          'Share the DartPad link or view the source at gist.github.com.';
      _textArea.style.display = 'none';

      MutableGist gist = gistContainer.mutableGist;

      content.add(_div);
      _padUrl.value = 'https://dartpad.dartlang.org/${gist.id}';
      _gistUrl.value = gist.html_url;

      buttonArea.add(new SpanElement()..attributes['flex'] = '');
      buttonArea.add(_closeButton);
    }
  }

  void _performShare() {
    _shareButton.disabled = true;

    // TODO: Show a spinner.
    gistController.shareAnon(summary: _textArea.value).then((_) {
      _switchTo(aboutToShare: false);
    }).whenComplete(() {
      _shareButton.disabled = false;
    });
  }
}

class KeysDialog extends DDialog {
  Map<Action, Set<String>> keyMap;

  KeysDialog(this.keyMap) : super(title: 'Keyboard shortcuts') {
    element.classes.toggle('keys-dialog', true);
    content.add(keyMapToHtml);
  }

  DListElement get keyMapToHtml {
    DListElement dl = new DListElement();
    keyMap.forEach((Action action, Set<String> keys) {
      if (!action.hidden) {
        String string = "";
        keys.forEach((key) {
          if (makeKeyPresentable(key) != null) {
            string += "<span>${makeKeyPresentable(key)}</span>";
          }
        });
        dl.innerHtml += "<dt>${action}</dt><dd>${string}</dd>";
      }
    });
    return dl;
  }

  // TODO: expose options
  //  DListElement get optionMapToHtml {
  //    DListElement dl = new DListElement();
  //    optionMap.forEach((key, value) {
  //      dl.innerHtml += "<dt>${capitalize(key.replaceAll("_"," "))}</dt>"
  //      '<dd><input type="checkbox" id="$key" ${options.getValueBool(key) ? "checked" : ""}></dd>';
  //    });
  //    return dl;
  //  }
}
