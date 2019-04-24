// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Thin JS interop wrapper around https://split.js.org/
@JS()
library splitter;

import 'dart:async';
import 'dart:html';

import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;

typedef _ElementStyleCallback = Function(
    Object dimension, Object size, num gutterSize, int index);
typedef _GutterStyleCallback = Function(
    Object dimension, num gutterSize, int index);

@JS()
@anonymous
class _SplitOptions {
  external factory _SplitOptions({
    _ElementStyleCallback elementStyle,
    _GutterStyleCallback gutterStyle,
    String direction,
    num gutterSize,
    List<num> sizes,
    List<num> minSize,
  });

  external _ElementStyleCallback get elementStyle;

  external _GutterStyleCallback get gutterStyle;

  external String get direction;

  external num get gutterSize;

  external List<num> get sizes;

  external List<num> get minSize;
}

@JS('Split')
external Splitter _split(List parts, _SplitOptions options);

@JS()
@anonymous
class Splitter {
  external void setSizes(List sizes);

  external List getSizes();

  external void collapse();

  external void destroy([bool preserveStyles, bool preserveGutters]);
}

/// Splitter that splits multiple elements that must be styled with flexbox
/// layout.
///
/// [parts] must be a list of [CoreElement], [Element], or query selectors.
///
/// The underlying split.js library supports splitting elements that use layout
/// schemes other than flexbox but we don't need that flexibility.
Splitter flexSplit(
  List parts, {
  bool horizontal = true,
  gutterSize = 5,
  List<num> sizes,
  List<num> minSize,
}) {
  return _split(
    parts.toList(),
    _SplitOptions(
      elementStyle: allowInterop((dimension, size, gutterSize, index) {
        return js_util.jsify({
          'flex-basis': 'calc($size% - ${gutterSize}px)',
        });
      }),
      gutterStyle: allowInterop((dimension, gutterSize, index) {
        return js_util.jsify({
          'flex-basis': '${gutterSize}px',
        });
      }),
      direction: horizontal ? 'horizontal' : 'vertical',
      gutterSize: gutterSize,
      sizes: sizes,
      minSize: minSize,
    ),
  );
}

/// Creates a splitter that changes from horizontal to vertical depending on the
/// window aspect ratio.
///
/// [parts] must be a list of [CoreElement], [Element], or query selectors.
///
/// To avoid memory leaks, cancel the stream subscription when the splitter is
/// no longer being used.
StreamSubscription<Object> flexSplitBidirectional(
  List parts, {
  gutterSize = 5,
  List<num> verticalSizes,
  List<num> horizontalSizes,
  List<num> minSize,
}) {
  final mediaQueryList = window.matchMedia('(min-aspect-ratio: 1/1)');
  Splitter splitter;
  // TODO(jacobr): cache the vertical or horizontal split and restore the value
  // when the aspect ratio changes back.
  void createSplitter() {
    final bool horizontal = mediaQueryList.matches;
    splitter = flexSplit(parts,
        horizontal: horizontal,
        gutterSize: gutterSize,
        minSize: minSize,
        sizes: horizontal ? horizontalSizes : verticalSizes);
  }

  createSplitter();
  return mediaQueryList.onChange.listen((e) {
    splitter.destroy(true, false);
    createSplitter();
  });
}
