// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The entrypoint for the **client** app.
///
/// This file is compiled to javascript and executed on the client when loading the page.
library;

// Ensures build_web_compilers copies conditional dart2wasm targets into scratchSpace
// (build_web_compilers sets dart.library.js=true and dart.library.isolate=false,
// whereas dart compile wasm sets dart.library.js=false and dart.library.isolate=true).
// ignore: unused_import, implementation_imports
import 'package:analyzer/src/generated/utilities_collection_native.dart';
// ignore: unused_import, implementation_imports
import 'package:archive/src/codecs/lzma/range_decoder_native.dart';
// ignore: unused_import, implementation_imports
import 'package:archive/src/util/_crc64_io.dart';
// Client-specific Jaspr import.
import 'package:jaspr/client.dart';

// Imports the [App] component.
import 'app.dart';

void main() {
  // Attaches the [App] component to the <body> of the page.
  runApp(const App());
}
