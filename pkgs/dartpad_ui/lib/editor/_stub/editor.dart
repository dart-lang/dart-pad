// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../model.dart';

class EditorWidgetImpl extends StatelessWidget {
  final AppModel appModel;
  final AppServices appServices;

  const EditorWidgetImpl({
    required this.appModel,
    required this.appServices,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Text('Editor Widget Implementation for MacOS');
  }
}
