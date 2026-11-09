// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Returns the names of WebAssembly features that the DartPad worker needs but
/// this browser lacks. An empty list means the worker can run.
///
/// Each feature is checked with `WebAssembly.validate` on a tiny module that
/// validates only when the engine implements that feature. The modules are
/// written out byte by byte, with comments, so the checks need no build step.
List<String> missingWasmFeatures() => [
  for (final probe in _probes)
    if (!probe.isSupported()) probe.name,
];

/// The message shown when [missing] is not empty.
String unsupportedBrowserMessage(List<String> missing) =>
    'This browser does not support WebAssembly features DartPad needs '
    '(${missing.join(', ')}). Use a recent version of Chrome, Edge, Firefox or Safari.';

final _probes = <({String name, bool Function() isSupported})>[
  (name: 'WasmGC', isSupported: () => _validate(_gcStructModule)),
  (name: 'exception handling (exnref)', isSupported: () => _validate(_tryTableModule)),
  // Declared with the wrong signature on purpose. An engine that knows the
  // builtins rejects the module, so `validate` returns false and this probe
  // passes. An engine that ignores the builtins option accepts the import, so
  // `validate` returns true and this probe fails.
  (
    name: 'JS string builtins',
    isSupported: () => !_validate(_jsStringCastModule, jsStringBuiltins: true),
  ),
  (name: 'SIMD', isSupported: () => _validate(_simdModule)),
  (name: 'JSTag', isSupported: _hasJsTag),
  (
    name: 'Firefox 147 or later',
    isSupported: () => !isFirefoxBelowMinVersion(web.window.navigator.userAgent),
  ),
];

/// Firefox version that Flutter's web support requires for WebAssembly.
///
/// Flutter gates Firefox below 147 by user agent version, not by feature
/// detection. The Firefox defect behind that gate is not confirmed here, so
/// `WebAssembly.validate` cannot detect it and this check reads the user agent.
const _firefoxMinVersion = 147;

/// Whether [userAgent] is Firefox older than [_firefoxMinVersion].
///
/// Other browsers, including Firefox on iOS, do not match `Firefox/<version>`.
bool isFirefoxBelowMinVersion(String userAgent) {
  final match = RegExp(r'Firefox/(\d+)').firstMatch(userAgent);
  return match != null && int.parse(match.group(1)!) < _firefoxMinVersion;
}

/// A module with one struct type: `(struct (field i32))`.
final _gcStructModule = _module([
  _section(1, [
    0x01, // one type
    0x5f, // struct
    0x01, // one field
    0x7f, // field type i32
    0x00, // field is immutable
  ]),
]);

/// A module with one function `() -> ()` whose body is
/// `try_table (catch_all 0) end`. Only exnref engines validate `try_table`.
final _tryTableModule = _module([
  _section(1, [
    0x01, // one type
    0x60, // func type
    0x00, // no parameters
    0x00, // no results
  ]),
  _section(3, [
    0x01, // one function
    0x00, // of type 0
  ]),
  _section(10, [
    0x01, // one function body
    ..._body([
      0x1f, // try_table
      0x40, // empty block type
      0x01, // one catch clause
      0x02, // catch_all
      0x00, // branch to label 0
      0x0b, // end of try_table
      0x0b, // end of function
    ]),
  ]),
]);

/// A module that imports `wasm:js-string.cast` as `() -> ()`.
///
/// The real `cast` takes an `externref`, so this signature is wrong on purpose.
/// See [_probes].
final _jsStringCastModule = _module([
  _section(1, [
    0x01, // one type
    0x60, // func type
    0x00, // no parameters
    0x00, // no results
  ]),
  _section(2, [
    0x01, // one import
    ..._name('wasm:js-string'), // module name
    ..._name('cast'), // field name
    0x00, // kind: function
    0x00, // type index 0
  ]),
]);

/// A module with one function `() -> v128` whose body is
/// `i8x16.popcnt(i8x16.splat(0))`.
final _simdModule = _module([
  _section(1, [
    0x01, // one type
    0x60, // func type
    0x00, // no parameters
    0x01, // one result
    0x7b, // v128
  ]),
  _section(3, [
    0x01, // one function
    0x00, // of type 0
  ]),
  _section(10, [
    0x01, // one function body
    ..._body([
      0x41, 0x00, // i32.const 0
      0xfd, 0x0f, // i8x16.splat
      0xfd, 0x62, // i8x16.popcnt
      0x0b, // end of function
    ]),
  ]),
]);

/// Wraps [sections] in a version 1 module header.
Uint8List _module(List<List<int>> sections) => Uint8List.fromList([
  // Magic number "\0asm".
  0x00, 0x61, 0x73, 0x6d,
  // Binary format version 1.
  0x01, 0x00, 0x00, 0x00,
  for (final section in sections) ...section,
]);

/// Encodes a section as its id, its size, and its contents.
///
/// The size is one byte, so contents must be shorter than 128 bytes. Every
/// probe fits.
List<int> _section(int id, List<int> contents) {
  assert(contents.length < 128, 'section too large for a one-byte size');
  return [id, contents.length, ...contents];
}

/// Encodes a function body with no locals, followed by [instructions].
///
/// The size is one byte, so the body must be shorter than 128 bytes.
List<int> _body(List<int> instructions) {
  final size = instructions.length + 1; // includes the locals count
  assert(size < 128, 'function body too large for a one-byte size');
  return [size, 0x00, ...instructions];
}

/// Encodes a name as its length followed by its ASCII bytes.
List<int> _name(String name) => [name.length, ...name.codeUnits];

/// Calls `WebAssembly.validate`.
///
/// When [jsStringBuiltins] is set, the options ask the engine to resolve the
/// JS string builtins.
bool _validate(Uint8List bytes, {bool jsStringBuiltins = false}) {
  final options = JSObject();
  if (jsStringBuiltins) {
    options.setProperty('builtins'.toJS, ['js-string'.toJS].toJS);
  }
  return _wasmValidate(bytes.toJS, options);
}

/// `WebAssembly.JSTag` is an exception tag that the worker imports.
bool _hasJsTag() {
  final JSObject wasm = web.WebAssembly;
  return wasm.hasProperty('JSTag'.toJS).toDart;
}

@JS('WebAssembly.validate')
external bool _wasmValidate(JSUint8Array bytes, JSObject options);
