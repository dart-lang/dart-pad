// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library context;

import 'dartservices_client/v1.dart';

abstract class Context {
  List<AnalysisIssue> issues = [];

  String get focusedEditor;

  String name;
  String description;

  String dartSource;
  String htmlSource;
  String cssSource;
}

abstract class ContextProvider {
  Context get context;
}

class BaseContextProvider extends ContextProvider {
  final Context context;
  BaseContextProvider(this.context);
}
