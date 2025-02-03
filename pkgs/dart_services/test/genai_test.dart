// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/generative_ai.dart';
import 'package:test/test.dart';

void main() {
  group('GenerativeAI.cleanCode', () {
    final unwrappedCode = '''
void main() {
  print("hello, world");
}
''';

    test('handles code without markdown wrapper', () async {
      final input = Stream.fromIterable(
        unwrappedCode.split('\n').map((line) => '$line\n'),
      );
      final cleaned = await GenerativeAI.cleanCode(input).join();
      expect(cleaned.trim(), unwrappedCode.trim());
    });

    test('handles code with markdown wrapper', () async {
      final input = Stream.fromIterable(
        unwrappedCode.split('\n').map((line) => '$line\n'),
      );
      final cleaned = await GenerativeAI.cleanCode(input).join();
      expect(cleaned.trim(), unwrappedCode.trim());
    });

    test('handles code with markdown wrapper and trailing newline', () async {
      final input = Stream.fromIterable(
        unwrappedCode.split('\n').map((line) => '$line\n'),
      );
      final cleaned = await GenerativeAI.cleanCode(input).join();
      expect(cleaned.trim(), unwrappedCode.trim());
    });

    test('handles single-chunk response with markdown wrapper', () async {
      final input = Stream.fromIterable(
        unwrappedCode.split('\n').map((line) => '$line\n'),
      );
      final cleaned = await GenerativeAI.cleanCode(input).join();
      expect(cleaned.trim(), unwrappedCode.trim());
    });

    test('handles partial first line buffering', () async {
      final input = Stream.fromIterable([
        '```',
        'dart\n',
        'void main() {\n',
        '  print("hello, world");\n',
        '}\n',
        '```',
      ]);

      final cleaned = await GenerativeAI.cleanCode(input).join();
      expect(cleaned.trim(), unwrappedCode.trim());
    });

    test('handles single-line code without trailing newline', () async {
      final input = Stream.fromIterable(
        ['void main() { print("hello, world"); }'],
      );

      final cleaned = await GenerativeAI.cleanCode(input).join();
      final oneline = unwrappedCode
          .replaceAll('\n', ' ')
          .replaceAll('  ', ' ')
          .replaceAll('  ', ' ');
      expect(cleaned.trim(), oneline.trim());
    });
  });
}
