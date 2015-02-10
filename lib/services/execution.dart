// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library execution;

import 'dart:async';

abstract class ExecutionService {
  Future execute(String html, String css, String javaScript);

  void replaceHtml(String html);
  void replaceCss(String css);

  Stream<String> get onStdout;
  Stream<String> get onStderr;
}
