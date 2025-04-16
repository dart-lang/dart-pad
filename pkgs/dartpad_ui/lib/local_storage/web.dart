// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
// import 'package:web/web.dart' as web;

import '../utils.dart';
import 'interface.dart';

const _userInputKey = 'user_input_';
const _userKeybindingKey = 'user_keybinding_';
const _lastCreateCodePromptKey = 'last_create_code_prompt_';
const _lastUpdateCodePromptKey = 'last_update_code_prompt_';
const _lastCreateCodeAppTypeKey = 'last_create_code_app_type_';

class LocalStorageImpl extends LocalStorageInterface {
  @override
  void saveUserCode(String code) => throw "tmp";
  // web.window.localStorage.setItem(_userInputKey, code);

  @override
  String? getUserCode() => throw "tmp";
  // web.window.localStorage.getItem(_userInputKey)?.nullIfEmpty;

  @override
  void saveUserKeybinding(String keybinding) => throw "tmp";
  // web.window.localStorage.setItem(_userKeybindingKey, keybinding);

  @override
  String? getUserKeybinding() => throw "tmp";
  // web.window.localStorage.getItem(_userKeybindingKey)?.nullIfEmpty;

  @override
  void saveLastCreateCodePrompt(String prompt) => throw "tmp";
  // web.window.localStorage.setItem(_lastCreateCodePromptKey, prompt);

  @override
  String? getLastCreateCodePrompt() => throw "tmp";
  // web.window.localStorage.getItem(_lastCreateCodePromptKey)?.nullIfEmpty;

  @override
  void saveLastUpdateCodePrompt(String prompt) => throw "tmp";
  // web.window.localStorage.setItem(_lastUpdateCodePromptKey, prompt);

  @override
  String? getLastUpdateCodePrompt() => throw "tmp";
  // web.window.localStorage.getItem(_lastUpdateCodePromptKey)?.nullIfEmpty;

  @override
  AppType getLastCreateCodeAppType() => throw "tmp";
  // {
  // final appType = web.window.localStorage.getItem(_lastCreateCodeAppTypeKey);
  // return AppType.values.firstWhere(
  //   (e) => e.name == appType,
  //   orElse: () => AppType.flutter,
  // );
  // }

  @override
  void saveLastCreateCodeAppType(AppType appType) => throw "tmp";
  //  web.window.localStorage.setItem(_lastCreateCodeAppTypeKey, appType.name);
}
