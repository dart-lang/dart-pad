// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web/web.dart' as web;

import '../utils.dart';

const _userInputKey = 'user_';

class LocalStorage {
  static final instance = LocalStorage();

  void saveUserCode(String code) =>
    web.window.localStorage.setItem(_userInputKey, code);

  String? getUserCode() =>
    web.window.localStorage.getItem(_userInputKey)?.nullIfEmpty;
}
