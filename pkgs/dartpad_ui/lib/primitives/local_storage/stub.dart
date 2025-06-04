// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';

import '../../model/utils.dart';

class DartPadLocalStorageImpl {
  String? _code;
  String? _keyBinding;
  String? _lastCreateCodePrompt;
  String? _lastUpdateCodePrompt;
  AppType _lastCreateCodeAppType = AppType.flutter;

  void saveUserCode(String code) => _code = code;

  void saveUserKeybinding(String keybinding) => _keyBinding = keybinding;

  void saveLastCreateCodePrompt(String prompt) =>
      _lastCreateCodePrompt = prompt;

  void saveLastUpdateCodePrompt(String prompt) =>
      _lastUpdateCodePrompt = prompt;

  String? getUserCode() => _code?.nullIfEmpty;

  String? getUserKeybinding() => _keyBinding?.nullIfEmpty;

  String? getLastCreateCodePrompt() => _lastCreateCodePrompt?.nullIfEmpty;

  String? getLastUpdateCodePrompt() => _lastUpdateCodePrompt?.nullIfEmpty;

  AppType getLastCreateCodeAppType() => _lastCreateCodeAppType;

  void saveLastCreateCodeAppType(AppType appType) =>
      _lastCreateCodeAppType = appType;
}
