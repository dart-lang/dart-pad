// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import 'js_types.dart';

/// Uses JS value equality when the operand types make the replacement safe.
final class UseJsEquality extends ResolvedCorrectionProducer {
  UseJsEquality({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind =>
      const FixKind('wasm_interop.useEquality', DartFixKindPriority.standard, 'Use JavaScript equality');

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final invocation = node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;
    final arguments = invocation.argumentList.arguments;
    final String replacement;
    if (invocation.methodName.name == 'identical' && arguments.length == 2) {
      // A Dart operand may override ==; erased types cannot establish JS equality.
      if (!arguments.every((argument) => isJsInteropType(argument.staticType))) return;
      final equality = '${_equalityOperand(arguments[0])} == ${_equalityOperand(arguments[1])}';
      replacement = _needsEqualityParentheses(invocation) ? '($equality)' : equality;
    } else if (invocation.methodName.name == 'same' && arguments.length == 1) {
      // same and equals are declared in separate libraries and re-exported by matcher.
      final library = await sessionHelper.session.getLibraryByUri('package:matcher/matcher.dart');
      if (library is! LibraryElementResult) return;
      final equals = library.element.exportNamespace.get2('equals');
      // Resolve the actual matcher function, preserving prefixes and imports.
      if (equals == null) return;
      await builder.addDartFileEdit(file, (edit) {
        edit.addReplacement(SourceRange(invocation.offset, invocation.length), (replacement) {
          replacement.writeReference(equals);
          replacement.write('(${getRangeText(SourceRange(arguments.single.offset, arguments.single.length))})');
        });
      });
      return;
    } else {
      return;
    }
    await builder.addDartFileEdit(file, (edit) {
      edit.addSimpleReplacement(SourceRange(invocation.offset, invocation.length), replacement);
    });
  }

  String _equalityOperand(Expression expression) {
    final source = getRangeText(SourceRange(expression.offset, expression.length));
    return expression.precedence <= Precedence.equality ? '($source)' : source;
  }

  bool _needsEqualityParentheses(MethodInvocation invocation) {
    final parent = invocation.parent;
    // Equality operators cannot be chained without parentheses, even at equal precedence.
    if (parent is BinaryExpression) return parent.precedence >= Precedence.equality;
    if (parent is PrefixExpression ||
        parent is PostfixExpression ||
        parent is AwaitExpression ||
        parent is AsExpression ||
        parent is IsExpression) {
      return true;
    }
    if (parent is MethodInvocation) return parent.target == invocation;
    if (parent is PropertyAccess) return parent.target == invocation;
    if (parent is IndexExpression) return parent.target == invocation;
    if (parent is CascadeExpression) return parent.target == invocation;
    if (parent is FunctionExpressionInvocation) return parent.function == invocation;
    // Delimited contexts (arguments, indexes, collections, records) need no wrapper.
    return false;
  }
}

/// Converts integer protocol fields, preserving nullable cast behavior.
final class ConvertJsNumberToInt extends ResolvedCorrectionProducer {
  ConvertJsNumberToInt({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => const FixKind(
    'wasm_interop.convertNumberToInt',
    DartFixKindPriority.standard,
    'Convert the numeric value to int',
  );

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final cast = node.thisOrAncestorOfType<AsExpression>();
    if (cast == null) return;
    final nullable = cast.type.type?.nullabilitySuffix == NullabilitySuffix.question;
    final expression = cast.expression;
    final source = getRangeText(SourceRange(expression.offset, expression.length));
    final sourceType = expression.staticType;
    final alreadyNumeric = sourceType != null && (sourceType.isDartCoreNum || sourceType.isDartCoreDouble);
    final sourceNullable = sourceType?.nullabilitySuffix == NullabilitySuffix.question;
    await builder.addDartFileEdit(file, (edit) {
      edit.addReplacement(SourceRange(cast.offset, cast.length), (replacement) {
        if (alreadyNumeric && (!sourceNullable || nullable)) {
          // Use the source nullability, not just the target: num as int? needs no ?.
          final receiver = expression.precedence < Precedence.postfix ? '($source)' : source;
          replacement.write(receiver);
          replacement.write(sourceNullable ? '?.toInt()' : '.toInt()');
          return;
        }
        // num? as num is a necessary null check; it also ends null-aware chains.
        replacement.write('($source as ');
        replacement.writeReference(typeProvider.numType.element);
        replacement.write(nullable ? '?)?.toInt()' : ').toInt()');
      });
    });
  }
}
