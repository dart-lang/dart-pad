// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.dialogs;

import 'dart:html';

import 'elements/elements.dart';

// TODO: closeable

// TODO: submit button

class SharingDialog extends DDialog {

  SharingDialog() {
    element.classes.toggle('sharing-dialog', true);

    var text = new ParagraphElement();
    text.text = 'Sharing this pad will create a permanent, publicly visible '
        'copy on gist.github.com.';
    element.children.add(text);
  }
}
