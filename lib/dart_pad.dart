// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad;

import 'package:route_hierarchical/client.dart';

import 'context.dart';
import 'core/dependencies.dart';
import 'core/event_bus.dart';
import 'core/keys.dart';
import 'dartservices_client/v1.dart';
import 'editing/editor.dart';
import 'elements/state.dart';
import 'services/execution.dart';
import 'sharing/gists.dart';
import 'src/ga.dart';
import 'src/options.dart';

Analytics get ga => deps[Analytics];

Context get context => deps[Context];

DartservicesApi get dartServices => deps[DartservicesApi];

EditorFactory get editorFactory => deps[EditorFactory];

EventBus get eventBus => deps[EventBus];

ExecutionService get executionService => deps[ExecutionService];

GistLoader get gistLoader => deps[GistLoader];

Keys get keys => deps[Keys];

Router get router => deps[Router];

State get state => deps[State];

Options get options => deps[Options];
