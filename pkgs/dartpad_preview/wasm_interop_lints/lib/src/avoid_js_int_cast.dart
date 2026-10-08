// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// Reports potentially unsafe integer casts in directly importing JS libraries.
final class AvoidJsIntCast extends AnalysisRule {
  static const code = LintCode(
    'avoid_js_int_cast',
    'An integer-valued JavaScript number can become a Dart double under Wasm.',
    correctionMessage: 'For integer protocol fields, use (value as num).toInt() instead of as int.',
  );

  AvoidJsIntCast()
    : super(name: 'avoid_js_int_cast', description: 'Avoid unchecked integer casts in JS interop libraries.');

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final imports = context.libraryElement?.fragments.expand((fragment) => fragment.importedLibraries);
    if (imports?.any((library) {
          final uri = library.uri.toString();
          return uri == 'dart:js_interop' || uri == 'dart:js_interop_unsafe';
        }) !=
        true) {
      return;
    }
    registry.addAsExpression(this, _Visitor(this));
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidJsIntCast rule;

  @override
  void visitAsExpression(AsExpression node) {
    if (node.type.type?.isDartCoreInt != true) return;
    final sourceType = node.expression.staticType;
    if (sourceType == null || sourceType.isDartCoreInt || sourceType.isDartCoreNull) return;
    if (sourceType is DynamicType ||
        sourceType.isDartCoreObject ||
        sourceType.isDartCoreNum ||
        sourceType.isDartCoreDouble) {
      rule.reportAtNode(node);
    }
  }
}
