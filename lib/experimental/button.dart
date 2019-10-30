// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'package:dart_pad/elements/elements.dart';
import 'package:mdc_web/mdc_web.dart';

/// Adds a ripple effect to material design buttons
class MDCButton extends DButton {
  final MDCRipple ripple;
  MDCButton(ButtonElement element, {bool isIcon = false})
      : ripple = MDCRipple(element)..unbounded = isIcon,
        super(element);
}
