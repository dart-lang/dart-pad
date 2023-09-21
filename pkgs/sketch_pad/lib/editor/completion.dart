// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:codemirror/hints.dart';

import '../src/dart_services.dart';

// TODO: Rework this to use the 'displayText' from the server?

class AnalysisCompletion implements Comparable<AnalysisCompletion> {
  final int offset;
  final int length;
  final CompletionSuggestion suggestion;

  AnalysisCompletion(this.offset, this.length, this.suggestion);

  CompletionElement? get _element => suggestion.element;

  String? get kind => suggestion.kind;

  bool get isMethod =>
      _element?.kind == 'FUNCTION' || _element?.kind == 'METHOD';

  bool get isConstructor => type == 'CONSTRUCTOR';

  String? get parameters => isMethod ? _element!.parameters : null;

  int? get parameterCount =>
      isMethod ? suggestion.parameterNames?.length : null;

  String get text {
    final str = suggestion.completion;
    if (str.startsWith('(') && str.endsWith(')')) {
      return str.substring(1, str.length - 1);
    } else {
      return str;
    }
  }

  String? get returnType => suggestion.returnType;

  bool get isDeprecated => suggestion.deprecated;

  int get selectionOffset => suggestion.selectionOffset;

  // FUNCTION, GETTER, CLASS, ...
  String? get type =>
      suggestion.element != null ? suggestion.element!.kind : kind;

  HintResult toCodemirrorHint() {
    var displayText = isMethod ? '$text$parameters' : text;
    if (isMethod && returnType != null) {
      displayText += ' → $returnType';
    }

    var replaceText = text;
    if (isMethod) {
      replaceText += '()';
    }
    if (isConstructor) {
      displayText += '()';
    }

    return HintResult(
      replaceText,
      displayText: displayText,
      className: isDeprecated ? 'deprecated' : null,
    );
  }

  @override
  int compareTo(AnalysisCompletion other) {
    return text.compareTo(other.text);
  }

  @override
  String toString() => text;
}
