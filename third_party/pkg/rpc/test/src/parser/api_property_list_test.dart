// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_property_list_tests;

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

class CorrectList {
  List<SomeClass> aList;

  @ApiProperty(name: 'anotherName', description: 'Description of a List.')
  List<SomeClass> aNamedList;

  @ApiProperty(required: true)
  List<SomeClass> aRequiredList;

  @ApiProperty(required: false)
  List<SomeClass> anOptionalList;

  @ApiProperty(
      name: 'aFullList', description: 'Description of a List.', required: true)
  List<SomeClass> aListWithAllAnnotations;

  @ApiProperty(ignore: true)
  List<SomeClass> ignored;
}

class WrongList {
  @ApiProperty(defaultValue: const [1, 2])
  List<int> aListWithDefault;

  @ApiProperty(minValue: 0, maxValue: 1)
  List<SomeClass> aListWithMinMax;

  @ApiProperty(format: 'int32')
  List<SomeClass> aListWithFormat;

  @ApiProperty(values: const {'enumValue': 'Enum Description'})
  List<SomeClass> aListWithEnumValues;
}

final ApiConfigSchema jsonSchema =
    new ApiParser().parseSchema(reflectClass(discovery.JsonSchema), false);

void main() {
  group('api-list-property-correct', () {
    test('simple', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectList), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 2);
      expect(parser.apiSchemas['CorrectList'], apiSchema);
      expect(parser.apiSchemas['SomeClass'], isNotNull);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectList',
        'type': 'object',
        'properties': {
          'aList': {
            'type': 'array',
            'items': {r'$ref': 'SomeClass'}
          },
          'anotherName': {
            'type': 'array',
            'description': 'Description of a List.',
            'items': {r'$ref': 'SomeClass'}
          },
          'aRequiredList': {
            'type': 'array',
            'required': true,
            'items': {r'$ref': 'SomeClass'}
          },
          'anOptionalList': {
            'type': 'array',
            'items': {r'$ref': 'SomeClass'}
          },
          'aFullList': {
            'type': 'array',
            'description': 'Description of a List.',
            'required': true,
            'items': {r'$ref': 'SomeClass'}
          }
        }
      };
      expect(json, expectedJson);
    });
  });

  group('api-list-property-wrong', () {
    test('simple', () {
      var parser = new ApiParser();
      parser.parseSchema(reflectClass(WrongList), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongList: aListWithDefault: Invalid property annotation. '
            'Property of type List<int> does not support the ApiProperty '
            'field: defaultValue'),
        new ApiConfigError(
            'WrongList: aListWithMinMax: Invalid property annotation. Property '
            'of type List<SomeClass> does not support the ApiProperty field: '
            'minValue'),
        new ApiConfigError(
            'WrongList: aListWithMinMax: Invalid property annotation. Property '
            'of type List<SomeClass> does not support the ApiProperty field: '
            'maxValue'),
        new ApiConfigError(
            'WrongList: aListWithFormat: Invalid property annotation. Property '
            'of type List<SomeClass> does not support the ApiProperty field: '
            'format'),
        new ApiConfigError(
            'WrongList: aListWithEnumValues: Invalid property annotation. '
            'Property of type List<SomeClass> does not support the ApiProperty '
            'field: values')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
