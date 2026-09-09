// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:codemirror_lang_dart/src/has_main_method.dart';
import 'package:test/test.dart';

void main() {
  group('hasMainMethod', () {
    test('detects standard void main()', () {
      expect(hasMainMethod('void main() {}'), isTrue);
    });

    test('detects main() with arguments', () {
      expect(hasMainMethod('void main(List<String> args) {}'), isTrue);
      expect(hasMainMethod('void main([List<String>? args]) {}'), isTrue);
      expect(hasMainMethod('void main({List<String>? args}) {}'), isTrue);
    });

    test('detects main() without return type', () {
      expect(hasMainMethod('main() {}'), isTrue);
      expect(hasMainMethod("main() => print('hello');"), isTrue);
    });

    test('detects async Future<void> main()', () {
      expect(hasMainMethod('Future<void> main() async {}'), isTrue);
      expect(hasMainMethod('Future main() async {}'), isTrue);
    });

    test('detects main() with preceding annotations and comments', () {
      const code = '''
/// The main application entrypoint.
@pragma('vm:entry-point')
void main() {
  runApp();
}
''';
      expect(hasMainMethod(code), isTrue);
    });

    test('ignores main inside a class', () {
      const code = '''
class App {
  void main() {}
}
''';
      expect(hasMainMethod(code), isFalse);
    });

    test('ignores main inside an enum, mixin, or extension', () {
      expect(
        hasMainMethod('''
enum Colors {
  red;
  void main() {}
}
'''),
        isFalse,
      );

      expect(
        hasMainMethod('''
mixin Runner {
  void main() {}
}
'''),
        isFalse,
      );

      expect(
        hasMainMethod('''
extension Ext on int {
  void main() {}
}
'''),
        isFalse,
      );
    });

    test('ignores top-level variables and getters named main', () {
      expect(hasMainMethod('var main = 42;'), isFalse);
      expect(hasMainMethod('final int main = 10;'), isFalse);
      expect(hasMainMethod('int get main => 42;'), isFalse);
      expect(hasMainMethod('class main {}'), isFalse);
    });

    test('ignores main inside comments', () {
      expect(hasMainMethod('// void main() {}'), isFalse);
      expect(hasMainMethod('/* void main() {} */'), isFalse);
      expect(hasMainMethod('/// void main() {}'), isFalse);
    });

    test('ignores main inside string literals', () {
      expect(hasMainMethod("var s = 'void main() {}';"), isFalse);
      expect(hasMainMethod('var s = "void main() {}";'), isFalse);
      expect(hasMainMethod("var s = '''void main() {}''';"), isFalse);
    });

    test('returns false for files without main', () {
      expect(hasMainMethod(''), isFalse);
      expect(hasMainMethod('void foo() {}'), isFalse);
      expect(hasMainMethod('class Widget {}'), isFalse);
    });

    test('correctly identifies main even if preceded by other declarations', () {
      const code = '''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Placeholder();
}

void main() {
  runApp(const MyWidget());
}
''';
      expect(hasMainMethod(code), isTrue);
    });
  });
}
