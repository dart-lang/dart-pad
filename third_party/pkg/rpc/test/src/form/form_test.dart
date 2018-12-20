// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library test.form.browser;

import 'dart:convert';
import 'dart:html';

import 'package:test/test.dart';

void main() {
  group('POST multipart/form-data', () {
    test('post-simple', () async {
      final form = new FormData()
        ..append('field1', 'hello')
        ..append('field2', 'world');
      final response = await HttpRequest.request(
          'http://localhost:4242/testAPI/v1/post/simple',
          method: 'POST',
          sendData: form);
      final result = jsonDecode(response.responseText);
      expect('hello', equals(result['field1']));
      expect('world', equals(result['field2']));
    });

    test('post-simple-mix', () async {
      final blobString =
          'Indescribable... Indestructible! Nothing can stop it!';
      final blob = new Blob([blobString], 'text/plain');
      final form = new FormData()
        ..append('field1', 'hello')
        ..appendBlob('field2', blob, 'theBlob.txt');
      final response = await HttpRequest.request(
          'http://localhost:4242/testAPI/v1/post/simple-mix',
          method: 'POST',
          sendData: form);
      final result = jsonDecode(response.responseText);

      expect('hello', equals(result['field1']));
      expect(blobString.codeUnits, equals(result['field2']['bytes']));
    });

    test('post-mega-mix', () async {
      final blobString =
          'Indescribable... Indestructible! Nothing can stop me!';
      final blob = new Blob([blobString], 'text/plain');
      final form = new FormData()
        ..append('name', 'John')
        ..append('age', '42')
        ..appendBlob('resume', blob, 'theResume.txt');
      final response = await HttpRequest.request(
          'http://localhost:4242/testAPI/v1/post/mega-mix',
          method: 'POST',
          sendData: form);
      final result = jsonDecode(response.responseText);

      expect('John', equals(result['name']));
      expect(42, equals(result['age']));
      expect(blobString.codeUnits, equals(result['resume']['bytes']));
    });
  });

  group('POST JSON', () {
    test('post-simple', () async {
      final request = {'field1': 'hello', 'field2': 'world'};
      final response = await HttpRequest.request(
          'http://localhost:4242/testAPI/v1/post/simple',
          method: 'POST',
          sendData: jsonEncode(request),
          requestHeaders: {'content-type': 'application/json;charset=UTF-8'});
      final result = jsonDecode(response.responseText);
      expect('hello', equals(result['field1']));
      expect('world', equals(result['field2']));
    });

    test('post-simple-mix', () async {
      final blobString =
          'Indescribable... Indestructible! Nothing can stop it!';
      final media = {'bytes': blobString.codeUnits};
      final request = {'field1': 'hello', 'field2': media};
      final response = await HttpRequest.request(
          'http://localhost:4242/testAPI/v1/post/simple-mix',
          method: 'POST',
          sendData: jsonEncode(request),
          requestHeaders: {'content-type': 'application/json;charset=UTF-8'});
      final result = jsonDecode(response.responseText);

      expect('hello', equals(result['field1']));
      expect(blobString.codeUnits, equals(result['field2']['bytes']));
    });

    test('post-mega-mix', () async {
      final blobString =
          'Indescribable... Indestructible! Nothing can stop me!';
      final media = {'bytes': blobString.codeUnits};
      final request = {'name': 'John', 'age': 42, 'resume': media};

      final response = await HttpRequest.request(
          'http://localhost:4242/testAPI/v1/post/mega-mix',
          method: 'POST',
          sendData: jsonEncode(request),
          requestHeaders: {'content-type': 'application/json;charset=UTF-8'});
      final result = jsonDecode(response.responseText);

      expect('John', equals(result['name']));
      expect(42, equals(result['age']));
      expect(blobString.codeUnits, equals(result['resume']['bytes']));
    });

    test('post-collection-list', () async {
      final blobString =
          'Indescribable... Indestructible! Nothing can stop me!';
      final media = {'bytes': blobString.codeUnits};
      final request = {
        'files': [media, media, media]
      };

      final response = await HttpRequest.request(
          'http://localhost:4242/testAPI/v1/post/collection/list',
          method: 'POST',
          sendData: jsonEncode(request),
          requestHeaders: {'content-type': 'application/json;charset=UTF-8'});
      final result = jsonDecode(response.responseText);

      expect(3, equals(result['files'].length));
      expect(blobString.codeUnits, equals(result['files'][1]['bytes']));
    });

    test('post-collection-map', () async {
      final blobString =
          'Indescribable... Indestructible! Nothing can stop me!';
      final media = {'bytes': blobString.codeUnits};
      final request = {
        'files': {'file1': media, 'file2': media, 'file3': media}
      };

      final response = await HttpRequest.request(
          'http://localhost:4242/testAPI/v1/post/collection/map',
          method: 'POST',
          sendData: jsonEncode(request),
          requestHeaders: {'content-type': 'application/json;charset=UTF-8'});
      final result = jsonDecode(response.responseText);

      expect(3, equals(result['files'].length));
      expect(blobString.codeUnits, equals(result['files']['file2']['bytes']));
    });
  });
}
