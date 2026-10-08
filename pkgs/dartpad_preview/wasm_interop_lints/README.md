# Wasm interop lints

Local analyzer plugin for Dart code compiled with both dart2js and dart2wasm.

## Rules

### `avoid_js_identity`

Reports `dart:core`'s `identical` and `package:matcher`'s `same` when an argument
has a JS interop type, including DOM extension types, generic JS bounds and
generic wrappers whose instantiated representation is a JS value.
Under Wasm, Dart wrapper identity can differ for the same underlying JS value.

```dart
// Before
identical(element, document.activeElement);
expect(actualNode, same(expectedNode));

// After (IDE quick fix available)
element == document.activeElement;
expect(actualNode, equals(expectedNode));
```

Ordinary Dart objects can still use `identical` and `same`. An argument whose
JS type has been erased to `Object` or `dynamic` cannot be identified by this rule.
The `identical` quick fix is only offered when both operands are known JS values:
a mixed Dart/JS comparison could invoke a Dart object's overridden `==` operator.

### `avoid_js_int_cast`

Reports casts from `dynamic`, `Object`, `num` or `double` to `int` or `int?` in
libraries that directly import `dart:js_interop` or `dart:js_interop_unsafe`.
This also covers parts of those libraries. Numbers returned by `dartify()` can
be `double` under Wasm, even when JavaScript holds an integer-valued number.

```dart
// Before
final line = position['line'] as int;
final optionalLine = position['line'] as int?;

// After (IDE quick fix available)
final line = (position['line'] as num).toInt();
final optionalLine = (position['line'] as num?)?.toInt();
```

This rule is deliberately conservative: it checks the whole importing library
because JS provenance is lost when values pass through maps and callbacks. It
does not track data flow across libraries, and can also flag casts on trusted
Dart/JSON values in an interop library.
Explicit `is int` checks and `int` patterns remain allowed: they intentionally
validate the Dart runtime type rather than convert a numeric protocol field.
Such checks do not accept integer-valued JS numbers represented as `double`.

The numeric quick fix is offered per location, not applied in bulk: use it for
integer protocol fields, since `toInt()` truncates fractional values. If a value
must already be a Dart `int`, retain that validation with a type check or pattern:

```dart
if (decoded case {'lastSeen': final int timestamp}) {
  lastSeen = timestamp;
}
```

For a justified exception, use a plugin-qualified suppression:

```dart
// ignore: wasm_interop_lints/avoid_js_int_cast
final count = trustedDartValue as int;
```
