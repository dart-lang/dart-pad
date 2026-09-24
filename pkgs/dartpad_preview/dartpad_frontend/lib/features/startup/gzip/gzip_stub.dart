// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Copied from https://github.com/dart-lang/pub/blob/a9ed06f7fb180b39b950aec878d4aa0911b7675e/lib/src/gzip/gzip_stub.dart

import 'dart:convert';

/// Default stub implementation of gzipDecoder.
Converter<List<int>, List<int>> get gzipDecoder =>
    throw UnsupportedError('gzipDecoder is not supported on this platform.');
