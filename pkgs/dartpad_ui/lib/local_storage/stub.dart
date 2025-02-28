// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';

import '../local_storage.dart';
import '../utils.dart';

class LocalStorageImpl extends LocalStorage {
  String? _code;
  String? _keyBinding;
  String? _lastCreateCodePrompt;
  String? _lastUpdateCodePrompt;
  AppType _lastCreateCodeAppType = AppType.flutter;

  @override
  void saveUserCode(String code) => _code = code;

  @override
  void saveUserKeybinding(String keybinding) => _keyBinding = keybinding;

  @override
  void saveLastCreateCodePrompt(String prompt) =>
      _lastCreateCodePrompt = prompt;

  @override
  void saveLastUpdateCodePrompt(String prompt) =>
      _lastUpdateCodePrompt = prompt;

  @override
  String? getUserCode() => _code?.nullIfEmpty;

  @override
  String? getUserKeybinding() => _keyBinding?.nullIfEmpty;

  @override
  String? getLastCreateCodePrompt() => _lastCreateCodePrompt?.nullIfEmpty;

  @override
  String? getLastUpdateCodePrompt() => _lastUpdateCodePrompt?.nullIfEmpty;

  @override
  AppType getLastCreateCodeAppType() => _lastCreateCodeAppType;

  @override
  void saveLastCreateCodeAppType(AppType appType) =>
      _lastCreateCodeAppType = appType;
}
