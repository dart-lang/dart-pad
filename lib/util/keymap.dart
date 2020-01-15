// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:dart_pad/core/keys.dart';

// HTML for keyboard shortcuts dialog
String keyMapToHtml(Map<Action, Set<String>> keyMap) {
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

  var keysDialogDiv = DivElement()
    ..children.add(dl)
    ..classes.add('keys-dialog');
  var div = DivElement()..children.add(keysDialogDiv);

  return div.innerHtml;
}
