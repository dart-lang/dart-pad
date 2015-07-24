// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.common;

//final String serverURL = 'https://dart-services.appspot.com/';
final String serverURL = 'http://export-api.dart-services.appspot.com';

final Duration serviceCallTimeout = new Duration(seconds: 10);
final Duration shortServiceCallTimeout = new Duration(seconds: 4);
final Duration longServiceCallTimeout = new Duration(seconds: 20);

abstract class TextProvider {
  // TODO: current location as well

  String getText();
}

class StringTextProvider {
  final String _text;
  StringTextProvider(this._text);
  String getText() => _text;
}

class Lines {
  List<int> _starts = [];

  Lines(String source) {
    List<int> units = source.codeUnits;
    bool nextIsEol = true;
    for (int i = 0; i < units.length; i++) {
      if (nextIsEol) {
        nextIsEol = false;
        _starts.add(i);
      }
      if (units[i] == 10) nextIsEol = true;
    }
  }

  /// Return the 0-based line number.
  int getLineForOffset(int offset) {
    if (_starts.isEmpty) return 0;
    for (int i = 1; i < _starts.length; i++) {
      if (offset < _starts[i]) return i - 1;
    }
    return _starts.length - 1;
  }

  int offsetForLine(int line) {
    assert(line >= 0);
    if (_starts.isEmpty) return 0;
    if (line >= _starts.length) line = _starts.length - 1;
    return _starts[line];
  }
}
