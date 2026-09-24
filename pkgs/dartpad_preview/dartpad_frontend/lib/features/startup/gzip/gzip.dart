// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Copied from https://github.com/dart-lang/pub/blob/a9ed06f7fb180b39b950aec878d4aa0911b7675e/lib/src/gzip/gzip.dart

import 'dart:convert';

import 'gzip_stub.dart' if (dart.library.io) 'gzip_io.dart' if (dart.library.js_interop) 'gzip_js.dart' as impl;

/// A [Converter] that decompresses gzip-compressed data.
Converter<List<int>, List<int>> get gzipDecoder => impl.gzipDecoder;
