// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.util;

import 'dart:async';
import 'dart:html';
import 'package:meta/meta.dart';

/// Return whether we are running on a mobile device.
bool isMobile() {
  final mobileSize = 610;

  var width = document.documentElement.clientWidth;
  var height = document.documentElement.clientHeight;

  return width <= mobileSize || height <= mobileSize;
}

/// A [NodeValidator] which allows everything.
class PermissiveNodeValidator implements NodeValidator {
  @override
  bool allowsElement(Element element) => true;

  @override
  bool allowsAttribute(Element element, String attributeName, String value) {
    return true;
  }
}

/// Text to be displayed to DartPad users. The associated title should be
/// 'About DartPad' (or equivalent).
final String privacyText = '''
DartPad is a free, open-source service to help developers learn about the Dart 
language and libraries. Source code entered into DartPad may be sent to servers 
running in Google Cloud Platform to be analyzed for errors/warnings, compiled 
to JavaScript, and returned to the browser.
<br><br>
Learn more about how DartPad stores your data in our
<a href="https://www.dartlang.org/tools/dartpad/privacy">privacy notice</a>.
We look forward to your
<a href="https://github.com/dart-lang/dart-pad/issues" target="feedback">feedback</a>.
<br><br>
Made with &lt;3 by Google.
''';

/// Thrown when a cancellation occurs whilst waiting for a result.
class CancellationException implements Exception {
  final String reason;

  CancellationException(this.reason);

  @override
  String toString() {
    var result = 'Request cancelled';
    if (reason != null) result = '$result due to: $reason';
    return result;
  }
}

class CancellableCompleter<T> implements Completer {
  final _completer = Completer<T>();
  bool _cancelled = false;

  CancellableCompleter();

  @override
  void complete([value]) {
    if (!_cancelled) _completer.complete(value as FutureOr<T>);
  }

  @override
  void completeError(Object error, [StackTrace stackTrace]) {
    if (!_cancelled) _completer.completeError(error, stackTrace);
  }

  @override
  Future<T> get future => _completer.future;

  @override
  bool get isCompleted => _completer.isCompleted;

  void cancel({String reason = 'cancelled'}) {
    if (!_cancelled) {
      if (!isCompleted) completeError(CancellationException(reason));
      _cancelled = true;
    }
  }

  bool get isCancelled => _cancelled;
}

String capitalize(String s) {
  if (s == null) {
    return null;
  } else if (s.length <= 1) {
    return s.toUpperCase();
  } else {
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }
}

/// Wait [duration] time after an event to fire on the returned stream, and
/// reset that time if a new event arrives.
Stream<T> debounceStream<T>(Stream<T> stream, Duration duration) {
  var controller = StreamController<T>.broadcast();

  Timer timer;

  stream.listen((T event) {
    timer?.cancel();
    timer = Timer(duration, () {
      controller.add(event);
    });
  });

  return controller.stream;
}

/// A typedef to represent a function taking no arguments and with no return
/// value.
typedef VoidFunction = void Function();

/// Batch up calls to the given closure. Repeated calls to [invoke] will
/// overwrite the closure to be called. We'll delay at least [minDelay] before
/// calling the closure, but will not delay more than [maxDelay].
class DelayedTimer {
  DelayedTimer({
    @required this.minDelay,
    @required this.maxDelay,
  });

  final Duration minDelay;
  final Duration maxDelay;

  VoidFunction _closure;

  Timer _minTimer;
  Timer _maxTimer;

  void invoke(VoidFunction closure) {
    _closure = closure;

    if (_minTimer == null) {
      _minTimer = Timer(minDelay, _fire);
      _maxTimer = Timer(maxDelay, _fire);
    } else {
      _minTimer.cancel();
      _minTimer = Timer(minDelay, _fire);
    }
  }

  void _fire() {
    _minTimer?.cancel();
    _minTimer = null;

    _maxTimer?.cancel();
    _maxTimer = null;

    _closure();
    _closure = null;
  }
}
