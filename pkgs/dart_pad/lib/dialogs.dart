// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'core/keys.dart';
import 'elements/elements.dart';
import 'src/util.dart';

/// Show an OK / Cancel dialog and return the option that the user selected.
class OkCancelDialog extends DDialog {
  OkCancelDialog(String title, String message, Future<void> Function() okAction,
      {String okText = 'OK', String cancelText = 'Cancel'})
      : super(title: title) {
    element.classes.toggle('sharing-dialog', true);
    content.add(ParagraphElement()).text = message;

    final cancelButton = buttonArea.add(DButton.button(text: cancelText));
    buttonArea.add(SpanElement()..attributes['flex'] = '');
    cancelButton.onClick.listen((_) => hide());

    final okButton =
        buttonArea.add(DButton.button(text: okText, classes: 'default'));
    okButton.onClick.listen((_) {
      okAction();
      hide();
    });
  }
}

class AboutDialog extends DDialog {
  AboutDialog([String? versionText]) : super(title: 'About DartPad') {
    final p = content.add(ParagraphElement());
    var text = privacyText;
    if (versionText != null) text += ' Based on Dart SDK $versionText.';
    p.setInnerHtml(text, validator: PermissiveNodeValidator());

    buttonArea.add(SpanElement()..attributes['flex'] = '');
    final okButton =
        buttonArea.add(DButton.button(text: 'OK', classes: 'default'));
    okButton.onClick.listen((_) => hide());
  }
}

class KeysDialog extends DDialog {
  Map<Action, Set<String>> keyMap;

  KeysDialog(this.keyMap) : super(title: 'Keyboard shortcuts') {
    element.classes.toggle('keys-dialog', true);
    content.add(keyMapToHtml);
  }

  DListElement get keyMapToHtml {
    final dl = DListElement();
    keyMap.forEach((Action action, Set<String> keys) {
      if (!action.hidden) {
        var string = '';
        for (final key in keys) {
          if (makeKeyPresentable(key) != null) {
            string += '<span>${makeKeyPresentable(key)}</span>';
          }
        }
        dl.innerHtml = '${dl.innerHtml ?? ''}<dt>$action</dt><dd>$string</dd>';
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
