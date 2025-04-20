// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import '../model.dart';
import '_stub/editor.dart'
    if (dart.library.js_interop) '_web/editor.dart'
    show EditorWidgetImpl;

class EditorWidget extends StatelessWidget {
  const EditorWidget({
    super.key,
    required this.appModel,
    required this.appServices,
  });

  final AppModel appModel;
  final AppServices appServices;

  @override
  Widget build(BuildContext context) {
    return EditorWidgetImpl(appModel: appModel, appServices: appServices);
  }
}
