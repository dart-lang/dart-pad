// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library codepad;

import 'context.dart';
import 'core/dependencies.dart';
import 'core/event_bus.dart';
import 'core/keys.dart';
import 'editing/editor.dart';
import 'elements/state.dart';
import 'services/analysis.dart';
import 'services/compiler.dart';
import 'services/execution.dart';

Context get context => deps[Context];

CompilerService get compilerService => deps[CompilerService];

AnalysisService get analysisService => deps[AnalysisService];

ExecutionService get executionService => deps[ExecutionService];

EventBus get eventBus => deps[EventBus];

Keys get keys => deps[Keys];

EditorFactory get editorFactory => deps[EditorFactory];

State get state => deps[State];
