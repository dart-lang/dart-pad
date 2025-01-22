// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../local_storage.dart';
import '../utils.dart';

class LocalStorageImpl extends LocalStorage {
  String? _code;
  String? _keyBinding;

  @override
  void saveUserCode(String code) => _code = code;

  @override
  void saveUserKeybinding(String keybinding) => _keyBinding = keybinding;

  @override
  String? getUserCode() => _code?.nullIfEmpty;

  @override
  String? getUserKeybinding() => _keyBinding?.nullIfEmpty;
}
