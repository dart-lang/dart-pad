// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_resource_tests;

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/utils.dart';
import 'package:test/test.dart';

@ApiClass(version: 'v1')
class CorrectResourceApi1 {
  @ApiResource()
  TestResource aResource = new TestResource();
}

@ApiClass(version: 'v1')
class CorrectResourceApi2 {
  @ApiResource(name: 'anotherResource')
  TestResource aResource = new TestResource();
}

@ApiClass(version: 'v1')
class CorrectResourceApi3 {
  @ApiResource()
  TestResource aResource = new TestResource();

  TestResource notExposedResource = new TestResource();
}

@ApiClass(version: 'v1')
class CorrectResourceApi4 {
  @ApiResource()
  TestResource aResource = new TestResource();

  @ApiResource()
  TestResource anotherResource = new TestResource();
}

@ApiClass(version: 'v1')
class WrongResourceApi1 {
  @ApiResource()
  void notAResource() {}
}

@ApiClass(version: 'v1')
class WrongResourceApi2 {
  @ApiResource()
  TestResource aResource = new TestResource();

  @ApiResource(name: 'aResource')
  TestResource anotherResourseWithDuplicateName = new TestResource();
}

class TestResource {}

void main() {
  group('api-resource-correct', () {
    test('correct-resource-api-1', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectResourceApi1());
      expect(apiCfg.resources.length, 1);
      ApiConfigResource resource = apiCfg.resources['aResource'];
      expect(resource, isNotNull);
      expect(resource.name, 'aResource');
      Map expectedResources = {
        'aResource': {'methods': {}, 'resources': {}}
      };
      var discoveryDoc = apiCfg.generateDiscoveryDocument('baseUrl', null);
      // Encode the discovery document for the Tester API as json.
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['resources'], expectedResources);
    });

    test('correct-resource-api-2', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectResourceApi2());
      expect(apiCfg.resources.length, 1);
      ApiConfigResource resource = apiCfg.resources['anotherResource'];
      expect(resource, isNotNull);
      expect(resource.name, 'anotherResource');
      // Make sure the default name is not used for the resource.
      expect(apiCfg.resources['aResource'], isNull);
      Map expectedResources = {
        'anotherResource': {'methods': {}, 'resources': {}}
      };
      var discoveryDoc = apiCfg.generateDiscoveryDocument('baseUrl', null);
      // Encode the discovery document for the Tester API as json.
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['resources'], expectedResources);
    });

    test('correct-resource-api-3', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectResourceApi3());
      expect(apiCfg.resources.length, 1);
      ApiConfigResource resource = apiCfg.resources['aResource'];
      expect(resource, isNotNull);
      expect(resource.name, 'aResource');
      // Make sure the field with no annotation is not part of the api.
      expect(apiCfg.resources['notExposedResource'], isNull);
      Map expectedResources = {
        'aResource': {'methods': {}, 'resources': {}}
      };
      var discoveryDoc = apiCfg.generateDiscoveryDocument('baseUrl', null);
      // Encode the discovery document for the Tester API as json.
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['resources'], expectedResources);
    });

    test('correct-resource-api-4', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectResourceApi4());
      expect(apiCfg.resources.length, 2);
      ApiConfigResource resource = apiCfg.resources['aResource'];
      expect(resource, isNotNull);
      expect(resource.name, 'aResource');
      resource = apiCfg.resources['anotherResource'];
      expect(resource, isNotNull);
      expect(resource.name, 'anotherResource');
      Map expectedResources = {
        'aResource': {'methods': {}, 'resources': {}},
        'anotherResource': {'methods': {}, 'resources': {}}
      };
      var discoveryDoc = apiCfg.generateDiscoveryDocument('baseUrl', null);
      // Encode the discovery document for the Tester API as json.
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['resources'], expectedResources);
    });
  });

  group('api-resource-wrong', () {
    test('wrong-resource-api-1', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongResourceApi1());
      expect(apiCfg.resources['notAResource'], isNull);
      expect(apiCfg.resources, isEmpty);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongResourceApi1: @ApiResource annotation on non-field: '
            '\'notAResource\'')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('wrong-resource-api-2', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongResourceApi2());
      ApiConfigResource resource = apiCfg.resources['aResource'];
      expect(resource, isNotNull);
      expect(apiCfg.resources.length, 1);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongResourceApi2: Duplicate resource with name: aResource')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
