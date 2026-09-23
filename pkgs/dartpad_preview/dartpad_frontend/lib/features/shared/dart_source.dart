// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
// Ensures build_web_compilers copies conditional dart2wasm targets into scratchSpace
// (build_web_compilers sets dart.library.js=true and dart.library.isolate=false,
// whereas dart compile wasm sets dart.library.js=false and dart.library.isolate=true).
// ignore: unused_import, implementation_imports
import 'package:analyzer/src/generated/utilities_collection_native.dart';
// ignore: unused_import, implementation_imports
import 'package:archive/src/codecs/lzma/range_decoder_native.dart';
// ignore: unused_import, implementation_imports
import 'package:archive/src/util/_crc64_io.dart';

/// Whether [source] declares a top-level, non-accessor function named `main`.
bool dartSourceHasMain(String source) => parseString(content: source, throwIfDiagnostics: false).unit.declarations
    .whereType<FunctionDeclaration>()
    .any((function) => function.name.lexeme == 'main' && !function.isGetter && !function.isSetter);
