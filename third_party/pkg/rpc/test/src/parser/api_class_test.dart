// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_class_tests;

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/utils.dart';
import 'package:test/test.dart';

@ApiClass(version: 'v1')
class CorrectMinimum {}

@ApiClass(
    name: 'testApi',
    version: 'v1',
    title: 'The Test API',
    description: 'An API used to test the implementation')
class CorrectFull {}

class WrongNoMetadata {}

@ApiClass()
class WrongNoVersionMinimum {}

@ApiClass(
    name: 'testApi',
    title: 'The Test API',
    description: 'An API used to test the implementation')
class WrongNoVersionFull {}

class MessageWithArguments {
  String result1;
  int result2;

  MessageWithArguments(this.result1, this.result2);
}

@ApiClass(version: 'v1')
class CorrectMessageWithArgsApi {
  @ApiMethod(path: 'simpleWithArgs')
  MessageWithArguments resultWithArgs() {
    return new MessageWithArguments('foo', 1);
  }

  @ApiMethod(path: 'mapResultWithArgs')
  Map<String, MessageWithArguments> mapResultWithArgs() {
    return {'foo': new MessageWithArguments('bar', 1)};
  }

  @ApiMethod(path: 'listResultWithArgs')
  List<MessageWithArguments> listResultWithArgs() {
    return [new MessageWithArguments('foo', 1)];
  }
}

@ApiClass(version: 'v1')
class InvalidMessageWithArgsApi {
  // We add this method to first parse the MessageWithArguments as a response
  // where it is valid and then have it fail when we try to parse it as a
  // request in the next method.
  @ApiMethod(method: 'GET', path: 'resultWithArgs')
  MessageWithArguments resultWithArgs() {
    return new MessageWithArguments('foo', 1);
  }

  @ApiMethod(method: 'POST', path: 'requestWithArgs')
  MessageWithArguments requestWithArgs(MessageWithArguments msg) {
    return new MessageWithArguments('foo', 1);
  }

  @ApiMethod(method: 'POST', path: 'mapRequestWithArgs')
  VoidMessage mapResultWithArgs(Map<String, MessageWithArguments> msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'listRequestWithArgs')
  VoidMessage listResultWithArgs(List<MessageWithArguments> msg) {
    return null;
  }
}

void main() {
  group('api-class-correct', () {
    test('full', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectFull());
      expect(parser.isValid, isTrue);
      expect(apiCfg.name, 'testApi');
      expect(apiCfg.version, 'v1');
      expect(apiCfg.title, 'The Test API');
      expect(apiCfg.description, 'An API used to test the implementation');
      var discoveryDoc =
          apiCfg.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedJson = {
        'kind': 'discovery#restDescription',
        'etag': '59760a6caa0688e9d6ecc50c3a90d923f03a8c3a',
        'discoveryVersion': 'v1',
        'id': 'testApi:v1',
        'name': 'testApi',
        'version': 'v1',
        'revision': '0',
        'title': 'The Test API',
        'description': 'An API used to test the implementation',
        'protocol': 'rest',
        'baseUrl': 'http://localhost:8080/testApi/v1/',
        'basePath': '/testApi/v1/',
        'rootUrl': 'http://localhost:8080/',
        'servicePath': 'testApi/v1/',
        'parameters': {},
        'schemas': {},
        'methods': {},
        'resources': {}
      };
      expect(json, expectedJson);
    });

    test('minimum', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectMinimum());
      expect(apiCfg.version, 'v1');
      // Check the defaults are as expected.
      expect(apiCfg.name, 'correctMinimum');
      expect(apiCfg.title, isNull);
      expect(apiCfg.description, isNull);
    });

    test('result-with-args', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectMessageWithArgsApi());
      expect(parser.isValid, isTrue);
      var discoveryDoc =
          apiCfg.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedJson = {
        'kind': 'discovery#restDescription',
        'etag': 'a1a0f4e178c4d5f1ab8d0ee2863ba84e9e92ec7b',
        'discoveryVersion': 'v1',
        'id': 'correctMessageWithArgsApi:v1',
        'name': 'correctMessageWithArgsApi',
        'version': 'v1',
        'revision': '0',
        'protocol': 'rest',
        'baseUrl': 'http://localhost:8080/correctMessageWithArgsApi/v1/',
        'basePath': '/correctMessageWithArgsApi/v1/',
        'rootUrl': 'http://localhost:8080/',
        'servicePath': 'correctMessageWithArgsApi/v1/',
        'parameters': {},
        'schemas': {
          'MessageWithArguments': {
            'id': 'MessageWithArguments',
            'type': 'object',
            'properties': {
              'result1': {'type': 'string'},
              'result2': {'type': 'integer', 'format': 'int32'}
            }
          },
          'MapOfMessageWithArguments': {
            'id': 'MapOfMessageWithArguments',
            'type': 'object',
            'additionalProperties': {r'$ref': 'MessageWithArguments'}
          },
          'ListOfMessageWithArguments': {
            'id': 'ListOfMessageWithArguments',
            'type': 'array',
            'items': {r'$ref': 'MessageWithArguments'}
          }
        },
        'methods': {
          'resultWithArgs': {
            'id': 'CorrectMessageWithArgsApi.resultWithArgs',
            'path': 'simpleWithArgs',
            'httpMethod': 'GET',
            'parameters': {},
            'parameterOrder': [],
            'response': {r'$ref': 'MessageWithArguments'}
          },
          'mapResultWithArgs': {
            'id': 'CorrectMessageWithArgsApi.mapResultWithArgs',
            'path': 'mapResultWithArgs',
            'httpMethod': 'GET',
            'parameters': {},
            'parameterOrder': [],
            'response': {r'$ref': 'MapOfMessageWithArguments'}
          },
          'listResultWithArgs': {
            'id': 'CorrectMessageWithArgsApi.listResultWithArgs',
            'path': 'listResultWithArgs',
            'httpMethod': 'GET',
            'parameters': {},
            'parameterOrder': [],
            'response': {r'$ref': 'ListOfMessageWithArguments'}
          }
        },
        'resources': {}
      };
      expect(json, expectedJson);
    });
  });

  group('api-class-wrong', () {
    test('no-metadata', () {
      var parser = new ApiParser();
      parser.parse(new WrongNoMetadata());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongNoMetadata: Missing required @ApiClass annotation.'),
        new ApiConfigError(
            'WrongNoMetadata: @ApiClass.version field is required.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('min-no-version', () {
      var parser = new ApiParser();
      parser.parse(new WrongNoVersionMinimum());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongNoVersionMinimum: @ApiClass.version field is required.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('full-no-version', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongNoVersionFull());
      expect(apiCfg.name, 'testApi');
      expect(apiCfg.version, isNull);
      expect(apiCfg.title, 'The Test API');
      expect(apiCfg.description, 'An API used to test the implementation');
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongNoVersionFull: @ApiClass.version field is required.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('request-with-args', () {
      var parser = new ApiParser();
      parser.parse(new InvalidMessageWithArgsApi());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'MessageWithArguments: Schema \'MessageWithArguments\' must have '
            'an unnamed constructor taking no arguments.'),
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
