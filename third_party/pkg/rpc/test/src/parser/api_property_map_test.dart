// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_property_map_tests;

import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/discovery/config.dart' as discovery;
import 'package:test/test.dart';

// Simple class used as a property type in the below unit tests.
class SomeClass {
  int foo;
  String bar;
}

class CorrectMap {
  Map<String, SomeClass> aMap;

  @ApiProperty(name: 'anotherName', description: 'Description of a Map.')
  Map<String, SomeClass> aNamedMap;

  @ApiProperty(required: true)
  Map<String, SomeClass> aRequiredMap;

  @ApiProperty(required: false)
  Map<String, SomeClass> anOptionalMap;

  @ApiProperty(
      name: 'aFullMap', description: 'Description of a Map.', required: true)
  Map<String, SomeClass> aMapWithAllAnnotations;

  @ApiProperty(ignore: true)
  Map<String, SomeClass> ignore;
}

class WrongMap {
  @ApiProperty(defaultValue: const {'foo': 1, 'bar': 2})
  Map<String, int> aMapWithDefault;

  @ApiProperty(minValue: 0, maxValue: 1)
  Map<String, SomeClass> aMapWithMinMax;

  @ApiProperty(format: 'int32')
  Map<String, SomeClass> aMapWithFormat;

  @ApiProperty(values: const {'enumValue': 'Enum Description'})
  Map<String, SomeClass> aMapWithEnumValues;
}

final ApiConfigSchema jsonSchema =
    new ApiParser().parseSchema(reflectClass(discovery.JsonSchema), false);

void main() {
  group('api-map-property-correct', () {
    test('simple', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectMap), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 2);
      expect(parser.apiSchemas['CorrectMap'], apiSchema);
      expect(parser.apiSchemas['SomeClass'], isNotNull);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectMap',
        'type': 'object',
        'properties': {
          'aMap': {
            'type': 'object',
            'additionalProperties': {r'$ref': 'SomeClass'}
          },
          'anotherName': {
            'type': 'object',
            'description': 'Description of a Map.',
            'additionalProperties': {r'$ref': 'SomeClass'}
          },
          'aRequiredMap': {
            'type': 'object',
            'required': true,
            'additionalProperties': {r'$ref': 'SomeClass'}
          },
          'anOptionalMap': {
            'type': 'object',
            'additionalProperties': {r'$ref': 'SomeClass'}
          },
          'aFullMap': {
            'type': 'object',
            'description': 'Description of a Map.',
            'required': true,
            'additionalProperties': {r'$ref': 'SomeClass'}
          }
        }
      };
      expect(json, expectedJson);
    });
  });

  group('api-map-property-wrong', () {
    test('simple', () {
      var parser = new ApiParser();
      parser.parseSchema(reflectClass(WrongMap), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongMap: aMapWithDefault: Invalid property annotation. Property '
            'of type Map<String, int> does not support the ApiProperty field: '
            'defaultValue'),
        new ApiConfigError(
            'WrongMap: aMapWithMinMax: Invalid property annotation. Property '
            'of type Map<String, SomeClass> does not support the ApiProperty '
            'field: minValue'),
        new ApiConfigError(
            'WrongMap: aMapWithMinMax: Invalid property annotation. Property '
            'of type Map<String, SomeClass> does not support the ApiProperty '
            'field: maxValue'),
        new ApiConfigError(
            'WrongMap: aMapWithFormat: Invalid property annotation. Property '
            'of type Map<String, SomeClass> does not support the ApiProperty '
            'field: format'),
        new ApiConfigError(
            'WrongMap: aMapWithEnumValues: Invalid property annotation. '
            'Property of type Map<String, SomeClass> does not support the '
            'ApiProperty field: values')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
