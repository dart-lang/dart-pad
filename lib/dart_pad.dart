// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad;

import 'context.dart';
import 'core/dependencies.dart';
import 'core/event_bus.dart';
import 'core/keys.dart';
import 'dartservices_client/v1.dart';
import 'editing/editor.dart';
import 'elements/state.dart';
import 'modules/dartservices_module.dart';
import 'services/execution.dart';

Context get context => deps[Context];

DartservicesApi get dartServices => deps[DartServices];

ExecutionService get executionService => deps[ExecutionService];

EventBus get eventBus => deps[EventBus];

Keys get keys => deps[Keys];

EditorFactory get editorFactory => deps[EditorFactory];

State get state => deps[State];
