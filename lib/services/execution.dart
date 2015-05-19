// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library execution;

import 'dart:async';

abstract class ExecutionService {
  Future execute(String html, String css, String javaScript);

  void replaceHtml(String html);
  void replaceCss(String css);

  /// Destroy the iframe; stop any currently running scripts. The iframe will be
  /// available to be re-used again.
  Future tearDown();

  Stream<String> get onStdout;
  Stream<String> get onStderr;
}
