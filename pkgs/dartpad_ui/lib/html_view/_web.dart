// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import '_stub.dart' as stub;

class DartPadHtmlViewImpl extends stub.DartPadHtmlViewImpl {
  const DartPadHtmlViewImpl({
    super.key,
    required super.viewType,
    super.onPlatformViewCreated,
  });

  @override
  Widget build(BuildContext context) => HtmlElementView(
    key: key,
    viewType: viewType,
    onPlatformViewCreated: onPlatformViewCreated,
  );
}
