// HTML for keyboard shortcuts dialog
import 'dart:html';

import 'package:dart_pad/core/keys.dart';

String keyMapToHtml(Map<Action, Set<String>> keyMap) {
  DListElement dl = DListElement();
  keyMap.forEach((Action action, Set<String> keys) {
    if (!action.hidden) {
      String string = '';
      for (final key in keys) {
        if (makeKeyPresentable(key) != null) {
          string += '<span>${makeKeyPresentable(key)}</span>';
        }
      }
      dl.innerHtml += '<dt>$action</dt><dd>$string</dd>';
    }
  });

  var keysDialogDiv = DivElement()
    ..children.add(dl)
    ..classes.add('keys-dialog');
  var div = DivElement()..children.add(keysDialogDiv);

  return div.innerHtml;
}
