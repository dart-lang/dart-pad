// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Returns the names of WebAssembly features that the DartPad worker needs but
/// this browser lacks. An empty list means the worker can run.
///
/// Each feature is checked with `WebAssembly.validate` on a tiny module that
/// validates only when the engine implements that feature.
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
];

/// `(module (type (struct (field i32))))`
///
/// Validates only when the engine implements WasmGC struct types.
final _gcStructModule = base64Decode('AGFzbQEAAAABBQFfAX8A');

/// `(module (func try_table (catch_all 0) end))`
///
/// Validates only when the engine implements exception handling with exnref,
/// which adds the `try_table` instruction.
final _tryTableModule = base64Decode('AGFzbQEAAAABBAFgAAADAgEACgoBCAAfQAECAAsL');

/// `(module (import "wasm:js-string" "cast" (func)))`
///
/// The real `cast` takes an `externref`, so this signature is wrong on purpose.
/// See [_probes].
final _jsStringCastModule = base64Decode('AGFzbQEAAAABBAFgAAACFwEOd2FzbTpqcy1zdHJpbmcEY2FzdAAA');

/// `(module (func (result v128) (i8x16.popcnt (i8x16.splat (i32.const 0)))))`
///
/// Validates only when the engine implements fixed-width SIMD.
final _simdModule = base64Decode('AGFzbQEAAAABBQFgAAF7AwIBAAoKAQgAQQD9D/1iCw==');

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
