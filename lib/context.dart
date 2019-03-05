// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library context;

import 'dart:async';

import 'services/dartservices.dart';

abstract class Context {
  List<AnalysisIssue> issues = [];

  String get focusedEditor;

  String name;
  String description;

  String dartSource;
  String htmlSource;
  String cssSource;

  String get activeMode;
  Stream<String> get onModeChange;
  void switchTo(String name);
}

abstract class ContextProvider {
  Context get context;
}

class BaseContextProvider extends ContextProvider {
  @override
  final Context context;
  BaseContextProvider(this.context);
}
