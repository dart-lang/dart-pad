// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_pad/inject/inject_parser.dart';
import 'package:test/test.dart';

void main() {
  group('InjectParser', () {
    test('can parse files', () {
      final parser = InjectParser(_codelab);
      final files = parser.read();
      expect(files, isNotEmpty);
      expect(files['main.dart'], "String message = 'Hello, World!';\n");
      expect(files['solution.dart'], "String message = 'delete your code';\n");
      expect(files['test.dart'], 'main() => print(message);\n');
    });

    test('throws with invalid input', () {
      expect(InjectParser(_invalidCodelab).read,
          throwsA(TypeMatcher<DartPadInjectException>()));
    });

    test('can parse normal snippets', () {
      final files = InjectParser(_normalSnippet).read();
      expect(files['main.dart'], equals("main() => print('Hello, World!');"));
    });
  });

  group('LanguageStringParser', () {
    test('recognizes run-dartpad class names', () {
      expect(LanguageStringParser('run-dartpad').isValid, isTrue);
      expect(LanguageStringParser('start-dartpad').isValid, isTrue);
      expect(LanguageStringParser('end-dartpad').isValid, isTrue);
      expect(LanguageStringParser('language-run-dartpad').isValid, isTrue);
      expect(LanguageStringParser('run-flutterpad').isValid, isFalse);
    });

    test('parses multi-snippet dartpad types', () {
      expect(LanguageStringParser('run-dartpad').isStart, isFalse);
      expect(LanguageStringParser('run-dartpad').isEnd, isFalse);
      expect(LanguageStringParser('start-dartpad').isStart, isTrue);
      expect(LanguageStringParser('end-dartpad').isEnd, isTrue);
    });

    test('supports options ', () {
      final options = LanguageStringParser('run-dartpad:mode-html:theme-dark'
              ':run-true:split-50:width-100%:height-400px:ga_id-example1:file-main.dart')
          .options;
      expect(options, isNotEmpty);
      expect(options['mode'], equals('html'));
      expect(options['theme'], equals('dark'));
      expect(options['run'], equals('true'));
      expect(options['split'], equals('50'));
      expect(options['width'], equals('100%'));
      expect(options['height'], equals('400px'));
      expect(options['ga_id'], equals('example1'));
      expect(options['file'], equals('main.dart'));
    });
  });
}

String _codelab = r'''
{$ begin main.dart $}
String message = 'Hello, World!';
{$ end main.dart $}

{$ begin solution.dart $}
String message = 'delete your code';
{$ end solution.dart $}

{$ begin test.dart $}
main() => print(message);
{$ end test.dart $}
''';

String _invalidCodelab = r'''
{$ begin main.dart $}
String message = 'Hello, World!';
{$ end main.dart $}

{$ begin solution.dart $}
String message = 'delete your code';
{$ begin main.dart $}
''';

String _normalSnippet = '''
main() => print('Hello, World!');
''';
