// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
// ignore: implementation_imports  // TODO: remove when https://github.com/dart-lang/sdk/issues/63822 is fixed
import 'package:analyzer/src/dart/scanner/scanner.dart';
// ignore: implementation_imports  // TODO: remove when https://github.com/dart-lang/sdk/issues/63822 is fixed
import 'package:analyzer/src/string_source.dart';

/// Checks whether the given Dart source [code] defines a top-level `main()` function.
bool hasMainMethod(String code) {
  final source = StringSource(code, '');
  final diagnosticCollector = RecordingDiagnosticListener();
  final diagnosticReporter = DiagnosticReporter(diagnosticCollector, source);

  final scanner = Scanner(code, diagnosticReporter)
    ..configureFeatures(
      featureSetForOverriding: FeatureSet.latestLanguageVersion(),
      featureSet: FeatureSet.latestLanguageVersion(),
    );
  var token = scanner.tokenize();

  var braceDepth = 0;
  while (token.type != TokenType.EOF) {
    if (token.type == TokenType.OPEN_CURLY_BRACKET) {
      braceDepth++;
    } else if (token.type == TokenType.CLOSE_CURLY_BRACKET) {
      if (braceDepth > 0) {
        braceDepth--;
      }
    } else if (braceDepth == 0 && token.type == TokenType.IDENTIFIER && token.lexeme == 'main') {
      if (token.next?.type == TokenType.OPEN_PAREN) {
        return true;
      }
    }
    token = token.next!;
  }
  return false;
}
