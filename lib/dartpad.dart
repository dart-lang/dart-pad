// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library liftoff;

import 'services/analysis.dart';
import 'services/compiler.dart';
import 'context.dart';
import 'core/dependencies.dart';
import 'editing/editor.dart';
import 'core/event_bus.dart';

Context get context => deps[Context];

CompilerService get compilerService => deps[CompilerService];

AnalysisIssueService get analysisService => deps[AnalysisIssueService];

EventBus get eventBus => deps[EventBus];

EditorFactory get editorFactory => deps[EditorFactory];
