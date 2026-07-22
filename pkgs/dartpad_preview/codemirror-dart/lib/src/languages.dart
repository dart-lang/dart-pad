// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@JS('window._codemirror')
library;

import 'dart:js_interop';

import 'package:codemirror_lang_dart/codemirror_lang_dart.dart' show dartLanguage;

import 'extensions.dart';
import 'types.dart';

@JS()
external JSAny yaml();

@JS()
external JSAny markdown();

@JS()
external JSAny javascript();

@JS()
external JSAny html();

@JS()
external JSAny css();

@JS()
external JSAny json();

@JS()
external JSAny xml();

@JS()
external JSAny sass();

@JS()
external JSAny sql();

JSObject dart() {
  final language = dartLanguage();

  final languageDataProvider = ((EditorState state, JSNumber pos, JSNumber side) {
    return [
          {
                'commentTokens':
                    {
                          'line': '//',
                          'block': {'open': '/*', 'close': '*/'},
                        }.jsify()
                        as JSObject,
              }.jsify()
              as JSObject,
        ].jsify()
        as JSArray;
  }).toJS;

  return [
        language,
        EditorState.languageData.of(languageDataProvider),
        keymapOf(
          [
            KeyBinding(
              key: 'Mod-/'.toJS,
              run: toggleLineComment,
            ),
            KeyBinding(
              key: 'Mod-Shift-7'.toJS,
              run: toggleLineComment,
            ),
            KeyBinding(
              key: 'Mod-Shift-/'.toJS,
              run: toggleLineComment,
            ),
            KeyBinding(
              key: 'Mod-Shift-Digit7'.toJS,
              run: toggleLineComment,
            ),
          ].toJS,
        ),
      ].jsify()
      as JSObject;
}
