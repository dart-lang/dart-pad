// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'local_storage/stub.dart'
    if (dart.library.js_util) 'local_storage/web.dart';

abstract class LocalStorage {
  static LocalStorage instance = LocalStorageImpl();

  void saveUserCode(String code);
  String? getUserCode();

  void saveUserKeybinding(String keybinding);
  String? getUserKeybinding();
}
