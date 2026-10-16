// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import 'js_types.dart';

/// Reports Dart identity checks whose arguments include JS interop values.
final class AvoidJsIdentity extends AnalysisRule {
  static const code = LintCode(
    'avoid_js_identity',
    'Dart identity checks compare JS wrapper identity under Wasm.',
    correctionMessage: 'Use == or equals(...) to compare the underlying JavaScript values.',
  );

  AvoidJsIdentity() : super(name: 'avoid_js_identity', description: 'Avoid Dart identity checks on JS interop values.');

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidJsIdentity rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name != 'identical' && name != 'same') return;
    final element = node.methodName.element;
    if (element is! TopLevelFunctionElement) return;
    final arguments = node.argumentList.arguments;
    final uri = element.library.uri;
    final isIdentical = element.name == 'identical' && uri.toString() == 'dart:core';
    final isSame = element.name == 'same' && uri.scheme == 'package' && uri.path.startsWith('matcher/');
    if ((isIdentical || isSame) && arguments.any((argument) => isJsInteropType(argument.staticType))) {
      rule.reportAtNode(node);
    }
  }
}
