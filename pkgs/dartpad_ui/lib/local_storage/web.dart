// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
import 'package:web/web.dart' as web;

import '../utils.dart';
import 'interface.dart';

const _userInputKey = 'user_input_';
const _userKeybindingKey = 'user_keybinding_';
const _lastCreateCodePromptKey = 'last_create_code_prompt_';
const _lastUpdateCodePromptKey = 'last_update_code_prompt_';
const _lastCreateCodeAppTypeKey = 'last_create_code_app_type_';

class LocalStorageImpl extends LocalStorageInterface {
  @override
  void saveUserCode(String code) =>
      web.window.localStorage.setItem(_userInputKey, code);

  @override
  String? getUserCode() =>
      web.window.localStorage.getItem(_userInputKey)?.nullIfEmpty;

  @override
  void saveUserKeybinding(String keybinding) =>
      web.window.localStorage.setItem(_userKeybindingKey, keybinding);

  @override
  String? getUserKeybinding() =>
      web.window.localStorage.getItem(_userKeybindingKey)?.nullIfEmpty;

  @override
  void saveLastCreateCodePrompt(String prompt) =>
      web.window.localStorage.setItem(_lastCreateCodePromptKey, prompt);

  @override
  String? getLastCreateCodePrompt() =>
      web.window.localStorage.getItem(_lastCreateCodePromptKey)?.nullIfEmpty;

  @override
  void saveLastUpdateCodePrompt(String prompt) =>
      web.window.localStorage.setItem(_lastUpdateCodePromptKey, prompt);

  @override
  String? getLastUpdateCodePrompt() =>
      web.window.localStorage.getItem(_lastUpdateCodePromptKey)?.nullIfEmpty;

  @override
  AppType getLastCreateCodeAppType() {
    final appType = web.window.localStorage.getItem(_lastCreateCodeAppTypeKey);
    return AppType.values.firstWhere(
      (e) => e.name == appType,
      orElse: () => AppType.flutter,
    );
  }

  @override
  void saveLastCreateCodeAppType(AppType appType) =>
      web.window.localStorage.setItem(_lastCreateCodeAppTypeKey, appType.name);
}
