// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

bool hasFlutterContent(String fileContent) {
  return fileContent.contains('package:flutter/') ||
      fileContent.contains('dart:ui');
}

bool hasHtmlContent(String fileContent) {
  return fileContent.contains('dart:html');
}
