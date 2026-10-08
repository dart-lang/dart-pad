// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// The reflective runner discovers test_<name> methods.
// ignore_for_file: non_constant_identifier_names

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart' show expect, isEmpty;
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:wasm_interop_lints/src/avoid_js_identity.dart';
import 'package:wasm_interop_lints/src/avoid_js_int_cast.dart';
import 'package:wasm_interop_lints/src/fixes.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(JsIdentityTest);
    defineReflectiveTests(JsIntCastTest);
  });
}

abstract class _RuleTest extends AnalysisRuleTest {
  Future<void> assertNoFix(
    String content,
    String target,
    ResolvedCorrectionProducer Function({required CorrectionProducerContext context}) createProducer,
  ) async {
    await assertDiagnostics(content, [lint(content.indexOf(target), target.length)]);
    final library = await result.session.getResolvedLibrary(result.path) as ResolvedLibraryResult;
    final builder = ChangeBuilder(session: result.session);
    await createProducer(
      context: CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: result,
        diagnostic: result.diagnostics.single,
        selectionOffset: content.indexOf(target),
        selectionLength: target.length,
      ),
    ).compute(builder);
    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> assertFix(
    String content,
    String target,
    String replacement,
    ResolvedCorrectionProducer Function({required CorrectionProducerContext context}) createProducer,
  ) async {
    await assertDiagnostics(content, [lint(content.indexOf(target), target.length)]);
    final library = await result.session.getResolvedLibrary(result.path) as ResolvedLibraryResult;
    final context = CorrectionProducerContext.createResolved(
      libraryResult: library,
      unitResult: result,
      diagnostic: result.diagnostics.single,
      selectionOffset: content.indexOf(target),
      selectionLength: target.length,
    );
    final builder = ChangeBuilder(session: result.session);
    await createProducer(context: context).compute(builder);
    final fixed = SourceEdit.applySequence(content, builder.sourceChange.edits.single.edits);
    expect(fixed, content.replaceFirst(target, replacement));
    await assertFixedCode(fixed);
  }

  Future<void> assertFixedCode(String content) async {
    // The test resource provider does not invalidate an already resolved file.
    final path = '$testPackageLibPath/fixed.dart';
    newFile(path, content);
    await assertNoDiagnosticsInFile(path);
  }
}

@reflectiveTest
final class JsIdentityTest extends _RuleTest {
  @override
  void setUp() {
    rule = AvoidJsIdentity();
    super.setUp();
    final matcher = newPackage('matcher');
    matcher.addFile('lib/matcher.dart', '''
export 'src/core_matchers.dart';
export 'src/equals_matcher.dart';
''');
    matcher.addFile('lib/src/core_matchers.dart', '''
bool same(Object? value) => true;
''');
    matcher.addFile('lib/src/equals_matcher.dart', '''
bool equals(Object? value) => true;
''');
    writeTestPackageConfig(PackageConfigFileBuilder());
  }

  Future<void> test_domExtensionTypeAndNullable() async {
    const content = '''
import 'dart:js_interop';
extension type Node(JSObject value) implements JSObject {}
bool f(Node? a, Node? b) => identical(a, b);
''';
    await assertDiagnostics(content, [lint(content.indexOf('identical'), 'identical(a, b)'.length)]);
  }

  Future<void> test_genericBound() async {
    const content = '''
import 'dart:js_interop';
bool f<T extends JSObject>(T a, T b) => identical(a, b);
''';
    await assertDiagnostics(content, [lint(content.indexOf('identical'), 'identical(a, b)'.length)]);
  }

  Future<void> test_nestedGenericRepresentation() async {
    const content = '''
import 'dart:js_interop';
extension type Wrapper<T>(T value) {}
bool f(Wrapper<Wrapper<JSObject>> a, Wrapper<Wrapper<JSObject>> b) => identical(a, b);
''';
    await assertDiagnostics(content, [lint(content.indexOf('identical'), 'identical(a, b)'.length)]);
  }

  Future<void> test_annotationAndGenericDartWrapperAllowed() async {
    await assertNoDiagnostics('''
import 'dart:js_interop';
extension type Wrapper<T extends Object>(T value) {}
bool f(JS a, JS b) => identical(a, b);
bool g(Wrapper<Object> a, Wrapper<Object> b) => identical(a, b);
bool h(Wrapper<JS> a, Wrapper<JS> b) => identical(a, b);
''');
  }

  Future<void> test_noFixForMixedDartAndJsOperands() async {
    await assertNoFix(
      '''
import 'dart:js_interop';
class DartValue {
  bool operator ==(Object other) => true;
  int get hashCode => 0;
}
bool f(DartValue a, JSObject b) => identical(a, b);
''',
      'identical(a, b)',
      UseJsEquality.new,
    );
  }

  Future<void> test_prefixedFunctionsAndMatcher() async {
    const content = '''
import 'dart:core' as core;
import 'dart:js_interop';
import 'package:matcher/matcher.dart' as test;
core.bool f(JSObject a, JSObject b) => core.identical(a, b);
core.bool g(JSObject a) => test.same(a);
''';
    await assertDiagnostics(content, [
      lint(content.indexOf('core.identical'), 'core.identical(a, b)'.length),
      lint(content.indexOf('test.same'), 'test.same(a)'.length),
    ]);
  }

  Future<void> test_dartValuesAndJsEqualityAllowed() async {
    await assertNoDiagnostics('''
import 'dart:js_interop';
import 'package:matcher/matcher.dart';
bool f(Object a, Object b) => identical(a, b);
bool g(Object a) => same(a);
bool h(JSObject a, JSObject b) => a == b;
bool i(JSObject a) => equals(a);
''');
  }

  Future<void> test_unrelatedFunctionNamedSameAllowed() async {
    await assertNoDiagnostics('''
import 'dart:js_interop';
bool same(JSObject a) => true;
bool f(JSObject a) => same(a);
''');
  }

  Future<void> test_fixIdenticalPreservesPrecedence() async {
    await assertFix(
      '''
import 'dart:js_interop';
bool f(JSObject a, JSObject b) => !identical(a, b);
''',
      'identical(a, b)',
      '(a == b)',
      UseJsEquality.new,
    );
  }

  Future<void> test_fixPrefixedSame() async {
    await assertFix(
      '''
import 'dart:js_interop';
import 'package:matcher/matcher.dart' as test;
bool f(JSObject a) => test.same(a);
''',
      'test.same(a)',
      'test.equals(a)',
      UseJsEquality.new,
    );
  }

  Future<void> test_fixConditionalArgumentAndComments() async {
    await assertFix(
      '''
import 'dart:js_interop';
bool f(bool choose, JSObject a, JSObject b) => identical(choose ? a /* keep */ : b, a);
''',
      'identical(choose ? a /* keep */ : b, a)',
      '(choose ? a /* keep */ : b) == a',
      UseJsEquality.new,
    );
  }

  Future<void> test_fixIdenticalInIfCondition() async {
    await assertFix(
      '''
import 'dart:js_interop';
bool f(JSObject a, JSObject b) {
  if (identical(a, b)) return true;
  return false;
}
''',
      'identical(a, b)',
      'a == b',
      UseJsEquality.new,
    );
  }

  Future<void> test_fixIdenticalAsEqualityOperand() async {
    await assertFix(
      '''
import 'dart:js_interop';
bool f(JSObject a, JSObject b, bool expected) => expected == identical(a, b);
''',
      'identical(a, b)',
      '(a == b)',
      UseJsEquality.new,
    );
  }

  Future<void> test_fixIdenticalAsMethodTarget() async {
    await assertFix(
      '''
import 'dart:js_interop';
String f(JSObject a, JSObject b) => identical(a, b).toString();
''',
      'identical(a, b)',
      '(a == b)',
      UseJsEquality.new,
    );
  }

  Future<void> test_fixIdenticalInCollection() async {
    await assertFix(
      '''
import 'dart:js_interop';
List<bool> f(JSObject a, JSObject b) => [identical(a, b)];
''',
      'identical(a, b)',
      'a == b',
      UseJsEquality.new,
    );
  }

  Future<void> test_fixIdenticalAsCascadeTarget() async {
    await assertFix(
      '''
import 'dart:js_interop';
bool f(JSObject a, JSObject b) => identical(a, b)..toString();
''',
      'identical(a, b)',
      '(a == b)',
      UseJsEquality.new,
    );
  }

  Future<void> test_fixGenericWrapper() async {
    await assertFix(
      '''
import 'dart:js_interop';
extension type Wrapper<T extends Object>(T value) {}
bool f(Wrapper<JSObject> a, Wrapper<JSObject> b) => identical(a, b);
''',
      'identical(a, b)',
      'a == b',
      UseJsEquality.new,
    );
  }

  Future<void> test_fixSameImportsEqualsWhenHidden() async {
    const content = '''
import 'dart:js_interop';
import 'package:matcher/matcher.dart' show same;
bool f(JSObject a) => same(a);
bool g(Object a) => same(a);
''';
    await assertDiagnostics(content, [lint(content.indexOf('same(a)'), 'same(a)'.length)]);
    final library = await result.session.getResolvedLibrary(result.path) as ResolvedLibraryResult;
    final builder = ChangeBuilder(session: result.session);
    await UseJsEquality(
      context: CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: result,
        selectionOffset: content.indexOf('same(a)'),
        selectionLength: 'same(a)'.length,
      ),
    ).compute(builder);
    final fixed = SourceEdit.applySequence(content, builder.sourceChange.edits.single.edits);
    expect(fixed.contains('equals(a)'), true);
    await assertFixedCode(fixed);
  }
}

@reflectiveTest
final class JsIntCastTest extends _RuleTest {
  @override
  void setUp() {
    rule = AvoidJsIntCast();
    super.setUp();
  }

  Future<void> test_dartifiedMapAndAliases() async {
    const content = '''
import 'dart:js_interop';
int f(JSObject edit) {
  final map = edit.dartify() as Map;
  final start = map['start'] as Map;
  final value = start['line'];
  return value as int;
}
''';
    await assertDiagnostics(content, [lint(content.indexOf('value as int'), 'value as int'.length)]);
  }

  Future<void> test_conversionAndPromotedIntAllowed() async {
    await assertNoDiagnostics('''
import 'dart:js_interop';
int f(JSObject edit) => (edit.dartify() as num).toInt();
int? g(JSObject edit) => (edit.dartify() as num?)?.toInt();
int? h(JSObject edit) {
  final value = edit.dartify();
  if (value is int) return value;
  return null;
}
int? i(JSObject edit) {
  if (edit.dartify() case {'line': final int line}) return line;
  return null;
}
''');
  }

  Future<void> test_nonInteropLibraryAllowed() async {
    await assertNoDiagnostics('''
int f(Map<String, Object?> decodedJson) => decodedJson['line'] as int;
''');
  }

  Future<void> test_trustedJsonInInteropLibraryStillReported() async {
    const content = '''
import 'dart:js_interop';
// The mock SDK omits jsonDecode; only its return type matters to this rule.
dynamic jsonDecode(String source) => null;
int f(JSObject edit, String json) => (jsonDecode(json) as Map)['line'] as int;
''';
    const target = "(jsonDecode(json) as Map)['line'] as int";
    await assertDiagnostics(content, [lint(content.indexOf(target), target.length)]);
  }

  Future<void> test_importInDefiningUnitCoversParts() async {
    newFile('$testPackageLibPath/main.dart', '''
// ignore: unused_import
import 'dart:js_interop';
part 'test.dart';
''');
    const content = '''
part of 'main.dart';
int f(Object value) => value as int;
''';
    await assertDiagnostics(content, [lint(content.indexOf('value as int'), 'value as int'.length)]);
  }

  Future<void> test_fixNullableIntegerField() async {
    await assertFix(
      '''
import 'dart:js_interop';
int? f(JSObject edit) => edit.dartify() as int?;
''',
      'edit.dartify() as int?',
      '(edit.dartify() as num?)?.toInt()',
      ConvertJsNumberToInt.new,
    );
  }

  Future<void> test_fixPrefixedCoreType() async {
    await assertFix(
      '''
import 'dart:core' as core;
import 'dart:js_interop';
core.int f(JSObject edit) => edit.dartify() as core.int;
''',
      'edit.dartify() as core.int',
      '(edit.dartify() as core.num).toInt()',
      ConvertJsNumberToInt.new,
    );
  }

  Future<void> test_fixNonNullableNumToNullableInt() async {
    await assertFix(
      '''
import 'dart:js_interop';
int? f(JSObject edit, num value) => value as int?;
''',
      'value as int?',
      'value.toInt()',
      ConvertJsNumberToInt.new,
    );
  }

  Future<void> test_fixNullableNumToNullableInt() async {
    await assertFix(
      '''
import 'dart:js_interop';
int? f(JSObject edit, num? value) => value as int?;
''',
      'value as int?',
      'value?.toInt()',
      ConvertJsNumberToInt.new,
    );
  }

  Future<void> test_fixNullAwareNumericGetterToNonNullableInt() async {
    await assertFix(
      '''
import 'dart:js_interop';
class Value { num get number => 0; }
int f(JSObject edit, Value? value) => value?.number as int;
''',
      'value?.number as int',
      '(value?.number as num).toInt()',
      ConvertJsNumberToInt.new,
    );
  }

  Future<void> test_fixNumericExpressionPreservesPrecedence() async {
    await assertFix(
      '''
import 'dart:js_interop';
int f(JSObject edit, num a, num b) => a + b as int;
''',
      'a + b as int',
      '(a + b).toInt()',
      ConvertJsNumberToInt.new,
    );
  }
}
