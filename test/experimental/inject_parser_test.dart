// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_pad/experimental/inject_parser.dart';
import 'package:test/test.dart';

main() {
  group('InjectParser', () {
    test('can parse files', () {
      var parser = InjectParser(_codelab);
      var files = parser.read();
      expect(files, isNotEmpty);
      expect(files['main.dart'], "String message = 'Hello, World!';\n");
      expect(files['solution.dart'], "String message = 'delete your code';\n");
      expect(files['test.dart'], "main() => print(message);\n");
    });

    test('throws with invalid input', () {
      expect(InjectParser(_invalidCodelab).read,
          throwsA(TypeMatcher<DartPadInjectException>()));
    });

    test('can parse normal snippets', () {
      var files = InjectParser(_normalSnippet).read();
      expect(files['main.dart'], equals("main() => print('Hello, World!');"));
    });
  });
}

String _codelab = '''
{% begin main.dart %}
String message = 'Hello, World!';
{% end main.dart %}

{% begin solution.dart %}
String message = 'delete your code';
{% end solution.dart %}

{% begin test.dart %}
main() => print(message);
{% end test.dart %}
''';

String _invalidCodelab = '''
{% begin main.dart %}
String message = 'Hello, World!';
{% end main.dart %}

{% begin solution.dart %}
String message = 'delete your code';
{% begin main.dart %}
''';

String _normalSnippet = '''
main() => print('Hello, World!');
''';
