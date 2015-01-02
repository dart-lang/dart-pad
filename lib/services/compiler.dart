// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_ui.compiler;

import 'dart:async';

abstract class CompilerService {
  Future<CompilerResult> compile(String source);
}

class CompilerResult {
  final String output;
  final List<CompilerIssue> issues;

  CompilerResult(this.output, [this.issues = const []]);

  bool get hasErrors => issues.isNotEmpty;

  bool get didFail => output == null;
}

class CompilerIssue {
  final String message;
  final String location;

  CompilerIssue(this.message, this.location);

  String toString() => '[${message}, ${location}]';
}
