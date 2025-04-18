// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '_stub.dart' if (dart.library.js_interop) '_web.dart';

abstract class DartPadLocalStorage {
  static DartPadLocalStorageImpl instance = DartPadLocalStorageImpl();
}
