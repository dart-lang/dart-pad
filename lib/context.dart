// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.9

library context;

import 'services/dartservices.dart';

abstract class ContextBase {
  bool get isFocused;
  String get dartSource;
  String get htmlSource;
  String get cssSource;
}

abstract class Context implements ContextBase {
  final List<AnalysisIssue> issues = [];

  String get focusedEditor;
  @override
  bool get isFocused => focusedEditor == 'dart';

  String name;
  String description;

  @override
  String dartSource;

  @override
  String htmlSource;

  @override
  String cssSource;

  String get activeMode;
  Stream<String> get onModeChange;
  void switchTo(String name);
}
