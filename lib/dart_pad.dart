// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad;

import 'package:http/browser_client.dart';

import 'context.dart';
import 'core/dependencies.dart';
import 'core/keys.dart';
import 'editing/editor.dart';
import 'elements/state.dart';
import 'services/dartservices.dart';
import 'sharing/gists.dart';
import 'src/ga.dart';

Analytics get ga => deps[Analytics] as Analytics;

Context get context => deps[Context] as Context;

DartservicesApi get dartServices => deps[DartservicesApi] as DartservicesApi;

EditorFactory get editorFactory => deps[EditorFactory] as EditorFactory;

GistLoader get gistLoader => deps[GistLoader] as GistLoader;

Keys get keys => deps[Keys] as Keys;

State get state => deps[State] as State;

BrowserClient get browserClient => deps[BrowserClient] as BrowserClient;
