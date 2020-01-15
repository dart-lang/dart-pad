// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library dart_pad.gists_test;

import 'package:dart_pad/sharing/gists.dart';
import 'package:dart_pad/sharing/gist_storage.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('gists', () {
    group('extractHtmlBody', () {
      test('should return empty string if html is empty', () {
        expect(extractHtmlBody(''), isEmpty);
      });

      test('should return body content if html is well-formed', () {
        expect(
            extractHtmlBody('<html><body><h1>Hello World!</h1></body></html>'),
            equals('<h1>Hello World!</h1>'));
        expect(
            extractHtmlBody(
                '<html>\n<body><h1>Hello World!</h1></body>\n</html>'),
            equals('<h1>Hello World!</h1>'));
      });

      test('should return empty string if html is well-formed but without body',
          () {
        expect(
            extractHtmlBody(
                '<html><head><title>Hello World!</title></head></html>'),
            isEmpty);
      });

      test('should return body content even if html is malformed', () {
        expect(extractHtmlBody('Hello World!'), equals('Hello World!'));
        expect(extractHtmlBody('<h1>Hello World!</h1>'),
            equals('<h1>Hello World!</h1>'));
        expect(
            extractHtmlBody(
                '<html><body><h1>Hello World!</h1></XXX></body></html>'),
            '<h1>Hello World!</h1></XXX>');
        //expect(extractHtmlBody('<html><body><h1>Hello World!</h1>'), '<h1>Hello World!</h1>');
        //expect(extractHtmlBody('<html><body><h1>Hello World!</h1></html>'), '<h1>Hello World!</h1>');
      });

      test('should return body content with external scripts or resources', () {
        var js = 'https://cdn.com/bootstrap.js';
        var css = 'https://cdn.com/bootstrap.css';
        expect(extractHtmlBody('<link rel="stylesheet" href="$css">'),
            equals('<link rel="stylesheet" href="$css">'));
        expect(extractHtmlBody('<script src="$js"></script>'),
            equals('<script src="$js"></script>'));
        expect(
            extractHtmlBody(
                '<html><body><script src="$js"></script></body></html>'),
            equals('<script src="$js"></script>'));
        expect(
            extractHtmlBody(
                '<script src="$js"></script><h1>Mixed script and content</h1>'),
            equals(
                '<script src="$js"></script><h1>Mixed script and content</h1>'));
      });

      test('should return body content with custom elements or attributes', () {
        expect(extractHtmlBody('<custom-element>Hello World!</custom-element>'),
            equals('<custom-element>Hello World!</custom-element>'));
        expect(extractHtmlBody('<h1 custom-attribute="Bob">Hello World!</h1>'),
            equals('<h1 custom-attribute="Bob">Hello World!</h1>'));
      });

      test('should avoid hacky body tags', () {
        expect(
            extractHtmlBody(
                '<html><body><h1>Hello <!-- </body> --> World!</h1></body></html>'),
            equals('<h1>Hello <!-- </body> --> World!</h1>'));
      });

      test('should preserve formatting', () {
        expect(extractHtmlBody(r'''<html>
<body>
<h1  class="awesome" >
  Hello World!

  <!-- Some comments
       <custom-comments> -->

  <input type='text'
    required >
</h1 >
</body>
</html>'''), equals(r'''<h1  class="awesome" >
  Hello World!

  <!-- Some comments
       <custom-comments> -->

  <input type='text'
    required >
</h1 >'''));
      });
    });

    test('clone', () {
      var gist = Gist(id: '2342jh2jh3g4', description: 'test gist');
      var clone = gist.clone();
      expect(clone.id, gist.id);
      expect(clone.description, gist.description);
    });
  });

  group('GistStorage', () {
    test('store', () {
      var storage = GistStorage();
      storage.setStoredGist(createSampleDartGist());
      expect(storage.hasStoredGist, true);
      expect(storage.getStoredGist(), isNotNull);
      expect(storage.storedId, null);
    });

    test('clear', () {
      var storage = GistStorage();
      storage.setStoredGist(createSampleDartGist());
      expect(storage.hasStoredGist, true);
      storage.clearStoredGist();
      expect(storage.hasStoredGist, false);
    });
  });
}
