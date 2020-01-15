// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:dart_pad/elements/elements.dart';

typedef ConsoleFilter = String Function(String line);

class Console {
  // The duration to wait before adding DOM elements to the document.
  final Duration bufferDuration;

  /// The element to append messages to.
  final DElement element;

  /// A filter function to apply to all messages.
  final ConsoleFilter filter;

  /// The CSS class name to apply to error messages.
  final String errorClass;

  final _bufferedOutput = <SpanElement>[];

  Console(
    this.element, {
    this.bufferDuration = const Duration(milliseconds: 32),
    this.filter,
    this.errorClass = 'error-output',
  });

  /// Displays console output. Does not clear the console.
  void showOutput(String message, {bool error = false}) {
    if (filter != null) {
      message = filter(message);
    }

    var span = SpanElement()..text = '$message\n';
    span.classes.add(error ? errorClass : 'normal');

    // Buffer the console output so that heavy writing to stdout does not starve
    // the DOM thread.
    _bufferedOutput.add(span);
    if (_bufferedOutput.length == 1) {
      Timer(bufferDuration, () {
        element.element.children.addAll(_bufferedOutput);
        // Using scrollIntoView(ScrollAlignment.BOTTOM) causes the parent page
        // to scroll, so set the scrollTop instead.
        var last = element.element.children.last;
        element.element.scrollTop = last.offsetTop;
        _bufferedOutput.clear();
      });
    }
  }

  void clear() {
    element.text = '';
  }
}
