// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';

/// Global styles that establish the document-level application layout.
@css
List<StyleRule> get appStyles => [
  css('html, body').styles(
    width: 100.percent,
    height: 100.percent,
    padding: .zero,
    margin: .zero,
    overflow: .hidden,
    color: const Color('#d4d4d4'),
    fontFamily: const .list([
      FontFamily('Inter'),
      FontFamily('Segoe UI'),
      FontFamilies.sansSerif,
    ]),
    backgroundColor: const Color('#1e1e1e'),
  ),
];
