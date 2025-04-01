// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';

abstract class LocalStorageInterface {
  void saveUserCode(String code);
  String? getUserCode();

  void saveUserKeybinding(String keybinding);
  String? getUserKeybinding();

  void saveLastCreateCodePrompt(String prompt);
  String? getLastCreateCodePrompt();

  void saveLastCreateCodeAppType(AppType appType);
  AppType getLastCreateCodeAppType();

  void saveLastUpdateCodePrompt(String prompt);
  String? getLastUpdateCodePrompt();
}
