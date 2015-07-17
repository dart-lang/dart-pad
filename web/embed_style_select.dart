// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.embed_style;

import 'dart:html' hide Document;

main() {
  _styleSelect();
}

void _lightStyle() {
  var cm = document.head.querySelector('link[href="packages/codemirror/theme/zenburn.css"]');
  if (cm != null) cm.attributes['href'] = 'zenburn-lite.css';
  var style = document.head.querySelector("#style_select");
  print("STYLE STYLE STYLE");
  print(style);
  if (style != null) {
    style.attributes['href'] = 'embed_style_lite.html';
  }
}

void _styleSelect() {
  Uri url = Uri.parse(window.location.toString());
  String style = url.queryParameters['style'];
  if (style == 'light') {
    _lightStyle();
    return;
  }
}