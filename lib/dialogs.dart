// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.dialogs;

import 'dart:html';

import 'core/keys.dart';
import 'elements/elements.dart';
import 'sharing/gists.dart';
import 'sharing/mutable_gist.dart';
import 'src/util.dart';

/**
 * Show an OK / Cancel dialog and return the option that the user selected.
 */
class OkCancelDialog extends DDialog {
  OkCancelDialog(String title, String message, Function okAction,
      {String okText = 'OK', String cancelText = 'Cancel'})
      : super(title: title) {
    element.classes.toggle('sharing-dialog', true);
    content.add(new ParagraphElement())..text = message;

    DButton cancelButton = buttonArea.add(new DButton.button(text: cancelText));
    buttonArea.add(new SpanElement()..attributes['flex'] = '');
    cancelButton.onClick.listen((_) => hide());

    DButton okButton =
        buttonArea.add(new DButton.button(text: okText, classes: 'default'));
    okButton.onClick.listen((_) {
      okAction();
      hide();
    });
  }
}

class AboutDialog extends DDialog {
  AboutDialog([String versionText]) : super(title: 'About DartPad') {
    ParagraphElement p = content.add(new ParagraphElement());
    String text = privacyText;
    if (versionText != null) text += " Based on Dart SDK ${versionText}.";
    p.setInnerHtml(text, validator: new PermissiveNodeValidator());

    buttonArea.add(new SpanElement()..attributes['flex'] = '');
    DButton okButton =
        buttonArea.add(new DButton.button(text: "OK", classes: 'default'));
    okButton.onClick.listen((_) => hide());
  }
}

class SharingDialog extends DDialog {
  final String home = 'dartpad.dartlang.org';
  final String _dartThumbnail = 'pictures/embed-dart.png';
  final String _htmlThumbnail = 'pictures/embed-html.png';
  final GistContainer gistContainer;
  final GistController gistController;

  ParagraphElement _text;
  TextAreaElement _textArea;
  DButton _cancelButton;
  DButton _closeButton;
  DButton _shareButton;
  DElement _div;
  DElement _embedArea;
  DElement _info;
  DInput _padUrl;
  DInput _gistUrl;
  DInput _embedUrl;
  GistSummary _gistSummary;

  ImageElement _embedPicture;

  RadioButtonInputElement _embedDartRadio;
  RadioButtonInputElement _embedHtmlRadio;

  SharingDialog(
      GistContainer this.gistContainer, GistController this.gistController)
      : super(title: 'Sharing') {
    element.classes.toggle('sharing-dialog', true);

    content.setAttr('layout');
    content.setAttr('vertical');

    _text = content.add(new ParagraphElement());
    _textArea = content.add(new TextAreaElement());
    _textArea.className = 'sharingSummaryText';
    _textArea.setAttribute('flex', '');

    // About to share.
    _cancelButton = new DButton.button(text: 'Cancel');
    _cancelButton.onClick.listen((_) => hide());
    _closeButton = new DButton.button(text: 'Close');
    _closeButton.onClick.listen((_) => hide());
    _shareButton = new DButton.button(text: 'Share it!', classes: 'default');
    _shareButton.onClick.listen((_) => _performShare());

    // Already sharing.
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
    div = _div.add(new DElement.tag('div', classes: 'row')..layoutHorizontal());
    div.add(new DElement.tag('span', classes: 'sharinglabel'))..text = 'Embed:';
    inputGroup = div.add(new DElement.tag('div'))
      ..layoutHorizontal()
      ..flex();
    _embedUrl = inputGroup.add(new DInput.input(type: 'text'))
      ..flex()
      ..readonly()
      ..value =
          "<iframe src='https://${home}/embed-dart.html?id=${gistContainer.mutableGist.id}' "
          "style='height:300px;width:100%;' frameborder='0'></iframe>";
    _embedUrl.onClick.listen((_) => _embedUrl.selectAll());
    div = _div.add(new DElement.tag('div', classes: 'row')..layoutHorizontal());
    _embedArea = div.add(new DElement.tag('div'))
      ..layoutHorizontal()
      ..flex();
    DElement _leftArea = _embedArea.add(new DElement.tag('div')
      ..layoutVertical()
      ..flex()
      ..element.style.paddingLeft = "16px");
    DElement _rightArea = _embedArea.add(new DElement.tag('div'));
    DElement _embedDartArea =
        _leftArea.add(new DElement.tag('div')..layoutHorizontal());
    DElement _embedHtmlArea =
        _leftArea.add(new DElement.tag('div')..layoutHorizontal());
    _embedDartRadio = _embedDartArea.add(new RadioButtonInputElement()
      ..name = "embed"
      ..id = "dart-radio");
    _embedDartArea.add(new LabelElement()
      ..htmlFor = 'dart-radio'
      ..text = 'Dart + documentation'
      ..style.paddingLeft = '8px');
    _embedHtmlRadio = _embedHtmlArea.add(new RadioButtonInputElement()
      ..name = "embed"
      ..id = "html-radio");
    _embedHtmlArea.add(new LabelElement()
      ..htmlFor = 'html-radio'
      ..text = 'Dart + HTML'
      ..style.paddingLeft = '8px');
    _embedDartRadio.checked = true;
    _embedPicture =
        _rightArea.add(new ImageElement(src: _dartThumbnail, height: 100)
          ..alt = "Embed-dart"
          ..style.paddingLeft = "16px");
    _embedDartRadio.onClick.listen((_) => _embedToDart());
    _embedHtmlRadio.onClick.listen((_) => _embedToHtml());
    _info = _leftArea.add(new DElement.tag('div')..layoutHorizontal());
    _info.add(new SpanElement()
      ..text = 'Check out our embedding '
      ..style.marginTop = '5px'
      ..append(new SpanElement()
        ..text = 'guide'
        ..attributes['onClick'] =
            "window.open('https://github.com/dart-lang/dart-pad/wiki/Embedding-Guide')"
        ..style.cursor = "pointer"
        ..style.textDecoration = "underline")
      ..append(new SpanElement()..text = '.'));
  }

  void _embedToDart() {
    _embedPicture.src = _dartThumbnail;
    _embedPicture.alt = "Embed-dart";
    _embedUrl.value =
        "<iframe src='https://${home}/embed-dart.html?id=${gistContainer.mutableGist.id}' "
        "style='height:300px;width:100%;' frameborder='0'></iframe>";
  }

  void _embedToHtml() {
    _embedPicture.src = _htmlThumbnail;
    _embedPicture.alt = "Embed-html";
    _embedUrl.value =
        "<iframe src='https://${home}/embed-html.html?id=${gistContainer.mutableGist.id}' "
        "style='height:300px;width:100%;' frameborder='0'></iframe>";
  }

  void showWithSummary(GistSummary summary) {
    this._gistSummary = summary;
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

  void _switchTo({bool aboutToShare = true}) {
    buttonArea.element.children.clear();
    _div.dispose();
    if (aboutToShare) {
      // Show 'about to share'.
      _text.text = 'Sharing this pad will create a permanent, publicly visible '
          'copy on gist.github.com.';
      _textArea.text = _gistSummary != null ? _gistSummary.summaryText : '';
      _textArea.style.display = 'block';

      buttonArea.add(_cancelButton);
      buttonArea.add(new SpanElement()..attributes['flex'] = '');
      buttonArea.add(_shareButton);
    } else {
      // Show the existing sharing info.
      _text.text =
          'Share the DartPad link or view the source at gist.github.com:';
      _textArea.style.display = 'none';
      MutableGist gist = gistContainer.mutableGist;
      content.add(_div);
      _padUrl.value = 'https://dartpad.dartlang.org/${gist.id}';
      _gistUrl.value = gist.html_url;
      _embedHtmlRadio.checked = false;
      _embedDartRadio.checked = true;
      _embedToDart();
      buttonArea.add(_closeButton);
      buttonArea.add(new SpanElement()..attributes['flex'] = '');
    }
  }

  void _performShare() {
    _shareButton.disabled = true;

    String text = _textArea.value;
    if (_gistSummary != null) text += '\n\n${_gistSummary.linkText}';

    gistController.shareAnon(summary: text).then((_) {
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
