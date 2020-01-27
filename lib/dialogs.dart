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

/// Show an OK / Cancel dialog and return the option that the user selected.
class OkCancelDialog extends DDialog {
  OkCancelDialog(String title, String message, Function okAction,
      {String okText = 'OK', String cancelText = 'Cancel'})
      : super(title: title) {
    element.classes.toggle('sharing-dialog', true);
    content.add(ParagraphElement())..text = message;

    var cancelButton = buttonArea.add(DButton.button(text: cancelText));
    buttonArea.add(SpanElement()..attributes['flex'] = '');
    cancelButton.onClick.listen((_) => hide());

    var okButton =
        buttonArea.add(DButton.button(text: okText, classes: 'default'));
    okButton.onClick.listen((_) {
      okAction();
      hide();
    });
  }
}

class AboutDialog extends DDialog {
  AboutDialog([String versionText]) : super(title: 'About DartPad') {
    var p = content.add(ParagraphElement());
    var text = privacyText;
    if (versionText != null) text += ' Based on Dart SDK $versionText.';
    p.setInnerHtml(text, validator: PermissiveNodeValidator());

    buttonArea.add(SpanElement()..attributes['flex'] = '');
    var okButton =
        buttonArea.add(DButton.button(text: 'OK', classes: 'default'));
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

  SharingDialog(this.gistContainer, this.gistController)
      : super(title: 'Sharing') {
    element.classes.toggle('sharing-dialog', true);

    content.setAttr('layout');
    content.setAttr('vertical');

    _text = content.add(ParagraphElement());
    _textArea = content.add(TextAreaElement());
    _textArea.className = 'sharingSummaryText';
    _textArea.setAttribute('flex', '');

    // About to share.
    _cancelButton = DButton.button(text: 'Cancel');
    _cancelButton.onClick.listen((_) => hide());
    _closeButton = DButton.button(text: 'Close');
    _closeButton.onClick.listen((_) => hide());
    _shareButton = DButton.button(text: 'Share it!', classes: 'default');

    // Already sharing.
    _div = DElement.tag('div')..layoutVertical();
    var div = _div.add(DElement.tag('div', classes: 'row')..layoutHorizontal());
    div.add(DElement.tag('span', classes: 'sharinglabel'))..text = 'DartPad:';
    var inputGroup = div.add(DElement.tag('div'))
      ..layoutHorizontal()
      ..flex();
    _padUrl = inputGroup.add(DInput.input(type: 'text'))
      ..flex()
      ..readonly();
    _padUrl.onClick.listen((_) => _padUrl.selectAll());

    div = _div.add(DElement.tag('div', classes: 'row')..layoutHorizontal());
    div.add(DElement.tag('span', classes: 'sharinglabel'))
      ..text = 'gist.github.com:';
    inputGroup = div.add(DElement.tag('div'))
      ..layoutHorizontal()
      ..flex();
    _gistUrl = inputGroup.add(DInput.input(type: 'text'))
      ..flex()
      ..readonly();
    _gistUrl.onClick.listen((_) => _gistUrl.selectAll());
    div = _div.add(DElement.tag('div', classes: 'row')..layoutHorizontal());
    div.add(DElement.tag('span', classes: 'sharinglabel'))..text = 'Embed:';
    inputGroup = div.add(DElement.tag('div'))
      ..layoutHorizontal()
      ..flex();
    _embedUrl = inputGroup.add(DInput.input(type: 'text'))
      ..flex()
      ..readonly()
      ..value =
          "<iframe src='https://$home/embed-dart.html?id=${gistContainer.mutableGist.id}' "
              "style='height:300px;width:100%;' frameborder='0'></iframe>";
    _embedUrl.onClick.listen((_) => _embedUrl.selectAll());
    div = _div.add(DElement.tag('div', classes: 'row')..layoutHorizontal());
    _embedArea = div.add(DElement.tag('div'))
      ..layoutHorizontal()
      ..flex();
    var _leftArea = _embedArea.add(DElement.tag('div')
      ..layoutVertical()
      ..flex()
      ..element.style.paddingLeft = '16px');
    var _rightArea = _embedArea.add(DElement.tag('div'));
    var _embedDartArea = _leftArea.add(DElement.tag('div')..layoutHorizontal());
    var _embedHtmlArea = _leftArea.add(DElement.tag('div')..layoutHorizontal());
    _embedDartRadio = _embedDartArea.add(RadioButtonInputElement()
      ..name = 'embed'
      ..id = 'dart-radio');
    _embedDartArea.add(LabelElement()
      ..htmlFor = 'dart-radio'
      ..text = 'Dart + documentation'
      ..style.paddingLeft = '8px');
    _embedHtmlRadio = _embedHtmlArea.add(RadioButtonInputElement()
      ..name = 'embed'
      ..id = 'html-radio');
    _embedHtmlArea.add(LabelElement()
      ..htmlFor = 'html-radio'
      ..text = 'Dart + HTML'
      ..style.paddingLeft = '8px');
    _embedDartRadio.checked = true;
    _embedPicture =
        _rightArea.add(ImageElement(src: _dartThumbnail, height: 100)
          ..alt = 'Embed-dart'
          ..style.paddingLeft = '16px');
    _embedDartRadio.onClick.listen((_) => _embedToDart());
    _embedHtmlRadio.onClick.listen((_) => _embedToHtml());
    _info = _leftArea.add(DElement.tag('div')..layoutHorizontal());
    _info.add(SpanElement()
      ..text = 'Check out our embedding '
      ..style.marginTop = '5px'
      ..append(SpanElement()
        ..text = 'guide'
        ..attributes['onClick'] =
            "window.open('https://github.com/dart-lang/dart-pad/wiki/Embedding-Guide')"
        ..style.cursor = 'pointer'
        ..style.textDecoration = 'underline')
      ..append(SpanElement()..text = '.'));
  }

  void _embedToDart() {
    _embedPicture.src = _dartThumbnail;
    _embedPicture.alt = 'Embed-dart';
    _embedUrl.value =
        "<iframe src='https://$home/embed-dart.html?id=${gistContainer.mutableGist.id}' "
        "style='height:300px;width:100%;' frameborder='0'></iframe>";
  }

  void _embedToHtml() {
    _embedPicture.src = _htmlThumbnail;
    _embedPicture.alt = 'Embed-html';
    _embedUrl.value =
        "<iframe src='https://$home/embed-html.html?id=${gistContainer.mutableGist.id}' "
        "style='height:300px;width:100%;' frameborder='0'></iframe>";
  }

  void showWithSummary(GistSummary summary) {
    _gistSummary = summary;
    show();
  }

  @override
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
      buttonArea.add(SpanElement()..attributes['flex'] = '');
      buttonArea.add(_shareButton);
    } else {
      // Show the existing sharing info.
      _text.text =
          'Share the DartPad link or view the source at gist.github.com:';
      _textArea.style.display = 'none';
      var gist = gistContainer.mutableGist;
      content.add(_div);
      _padUrl.value = 'https://dartpad.dartlang.org/${gist.id}';
      _gistUrl.value = gist.htmlUrl;
      _embedHtmlRadio.checked = false;
      _embedDartRadio.checked = true;
      _embedToDart();
      buttonArea.add(_closeButton);
      buttonArea.add(SpanElement()..attributes['flex'] = '');
    }
  }
}

class KeysDialog extends DDialog {
  Map<Action, Set<String>> keyMap;

  KeysDialog(this.keyMap) : super(title: 'Keyboard shortcuts') {
    element.classes.toggle('keys-dialog', true);
    content.add(keyMapToHtml);
  }

  DListElement get keyMapToHtml {
    var dl = DListElement();
    keyMap.forEach((Action action, Set<String> keys) {
      if (!action.hidden) {
        var string = '';
        for (final key in keys) {
          if (makeKeyPresentable(key) != null) {
            string += '<span>${makeKeyPresentable(key)}</span>';
          }
        }
        dl.innerHtml += '<dt>$action</dt><dd>$string</dd>';
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
