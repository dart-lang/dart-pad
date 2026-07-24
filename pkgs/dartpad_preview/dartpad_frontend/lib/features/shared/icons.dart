// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// A small Feather-style close icon.
Component closeIcon({double size = 12}) {
  return svg(
    viewBox: '0 0 24 24',
    attributes: {
      'aria-hidden': 'true',
      'width': '$size',
      'height': '$size',
      'fill': 'none',
      'stroke': 'currentColor',
      'stroke-width': '2.5',
      'stroke-linecap': 'round',
      'stroke-linejoin': 'round',
    },
    [
      const line(x1: '18', y1: '6', x2: '6', y2: '18', []),
      const line(x1: '6', y1: '6', x2: '18', y2: '18', []),
    ],
  );
}
