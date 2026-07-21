// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'package:codemirror_lang_dart/codemirror_lang_dart.dart';

@JS('window.runBenchmark')
external void runBenchmark(JSFunction parseCallback);

void main() {
  runBenchmark(parseCodeCallback.toJS);
}
