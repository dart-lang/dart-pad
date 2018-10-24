// Copyright (c) 2015, Atrox. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library Haikunator.test;

import 'package:test/test.dart';
import 'package:haikunator/haikunator.dart';

main() {
  group('testing haikunate', () {
    test('should return 4 digits', () {
      String haiku = Haikunator.haikunate();
      expect(
          haiku, matches(r'((?:[a-z][a-z]+))(-)((?:[a-z][a-z]+))(-)(\d{4})$'));
    });

    test('should return 4 digits as hex', () {
      String haiku = Haikunator.haikunate(tokenHex: true);
      expect(
          haiku, matches(r'((?:[a-z][a-z]+))(-)((?:[a-z][a-z]+))(-)(.{4})$'));
    });

    test('should return 9 digits', () {
      String haiku = Haikunator.haikunate(tokenLength: 9);
      expect(
          haiku, matches(r'((?:[a-z][a-z]+))(-)((?:[a-z][a-z]+))(-)(\d{9})$'));
    });

    test('should return 9 digits as hex', () {
      String haiku = Haikunator.haikunate(tokenLength: 9, tokenHex: true);
      expect(
          haiku, matches(r'((?:[a-z][a-z]+))(-)((?:[a-z][a-z]+))(-)(.{9})$'));
    });

    test('wont return the same name for subsequent calls', () {
      expect(Haikunator.haikunate(), isNot(equals(Haikunator.haikunate())));
    });

    test('drops the token if token range is 0', () {
      String haiku = Haikunator.haikunate(tokenLength: 0);
      expect(haiku, matches(r'((?:[a-z][a-z]+))(-)((?:[a-z][a-z]+))$'));
    });

    test('permits optional configuration of the delimiter', () {
      String haiku = Haikunator.haikunate(delimiter: '.');
      expect(
          haiku, matches(r'((?:[a-z][a-z]+))(\.)((?:[a-z][a-z]+))(\.)(\d+)$'));
    });

    test('drops the token if token range is 0 and delimiter is an empty space',
        () {
      String haiku = Haikunator.haikunate(tokenLength: 0, delimiter: ' ');
      expect(haiku, matches(r'((?:[a-z][a-z]+))( )((?:[a-z][a-z]+))$'));
    });

    test('returns one single word if token and delimiter are dropped', () {
      String haiku = Haikunator.haikunate(tokenLength: 0, delimiter: '');
      expect(haiku, matches(r'((?:[a-z][a-z]+))$'));
    });

    test('permits custom token chars', () {
      String haiku = Haikunator.haikunate(tokenChars: 'A');
      expect(
          haiku, matches(r'((?:[a-z][a-z]+))(-)((?:[a-z][a-z]+))(-)(AAAA)$'));
    });
  });
}
