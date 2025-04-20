// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
import 'package:flutter/widgets.dart';

import '../../model.dart';

class ConcreteEditorServiceImpl implements EditorService {
  FocusableActionDetector focusableActionDetector(bool darkMode) =>
      FocusableActionDetector(child: SizedBox());

  ConcreteEditorServiceImpl(AppModel appModel, AppServices appServices);

  @override
  int get cursorOffset => 0;

  @override
  void focus() {}

  @override
  void jumpTo(AnalysisIssue issue) {}

  @override
  void refreshViewAfterWait() {}

  @override
  void showCompletions({required bool autoInvoked}) {}

  @override
  void showQuickFixes() {}

  void updateCodemirrorMode(bool darkMode) {}

  void updateCodemirrorFromModel() {}

  void updateCodemirrorKeymap() {}

  void updateEditableStatus() {}
}
