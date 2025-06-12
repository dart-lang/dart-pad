// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

class DartPadHtmlViewImpl extends StatelessWidget {
  final String viewType;
  final void Function(int)? onPlatformViewCreated;

  const DartPadHtmlViewImpl({
    super.key,
    required this.viewType,
    this.onPlatformViewCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Text('Placeholder for HtmlElementView, available on web only.');
  }
}
