// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:codemirror/hints.dart';
import 'package:dartpad_shared/model.dart';

// TODO: Rework this to use the 'displayText' from the server

class AnalysisCompletion {
  final int offset;
  final int length;
  final CompletionSuggestion suggestion;

  AnalysisCompletion(this.offset, this.length, this.suggestion);

  String? get elementKind => suggestion.elementKind;

  bool get isConstructor => elementKind == 'CONSTRUCTOR';

  bool get isMethod => elementKind == 'FUNCTION' || elementKind == 'METHOD';

  String? get returnType => suggestion.returnType;

  bool get isDeprecated => suggestion.deprecated;

  HintResult toCodemirrorHint() {
    final replaceText = suggestion.completion;

    var displayText = suggestion.displayText;
    if (displayText == null) {
      displayText = suggestion.completion;
      if (isMethod || isConstructor) {
        displayText += '()';
      }
    }

    return HintResult(
      replaceText,
      displayText: displayText,
      className: isDeprecated ? 'deprecated' : null,
    );
  }

  @override
  String toString() => suggestion.completion;
}
