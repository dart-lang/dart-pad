// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_frontend/features/startup/initial_project_state.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:dartpad_frontend/sdks.g.dart';

Project testProjectContents(Map<String, String> files) => Project([
  for (final entry in files.entries) ProjectFile(path: entry.key, bytes: Uint8List.fromList(utf8.encode(entry.value))),
]);

InitialProjectState testProject({String query = '?sdk=flutter', Map<String, String>? files}) =>
    InitialProjectState.resolve(
      ProjectRequest.fromUri(Uri.parse(query)),
      testProjectContents(files ?? {'lib/main.dart': 'void main() {}'}),
      availableSdks,
    );
