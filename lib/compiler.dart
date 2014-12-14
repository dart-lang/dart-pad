

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
