// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_property_class_tests;

import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/discovery/config.dart' as discovery;
import 'package:test/test.dart';

// Simple class used as a property type in the below unittests.
class SomeClass {
  int foo;
  String bar;
}

class CorrectClass {
  SomeClass aClass;

  @ApiProperty(name: 'anotherName', description: 'Description of a Class.')
  SomeClass aNamedClass;

  @ApiProperty(required: true)
  SomeClass aRequiredClass;

  @ApiProperty(required: false)
  SomeClass anOptionalClass;

  @ApiProperty(
      name: 'aFullClass',
      description: 'Description of a Class.',
      required: true)
  SomeClass aClassWithAllAnnotations;

  @ApiProperty(ignore: true)
  SomeClass ignored;
}

class WrongClass {
  @ApiProperty(defaultValue: 'A const class value?')
  SomeClass aClassWithDefault;

  @ApiProperty(minValue: 0, maxValue: 1)
  SomeClass aClassWithMinMax;

  @ApiProperty(format: 'int32')
  SomeClass aClassWithFormat;

  @ApiProperty(values: const {'enumValue': 'Enum Description'})
  SomeClass aClassWithEnumValues;
}

final ApiConfigSchema jsonSchema =
    new ApiParser().parseSchema(reflectClass(discovery.JsonSchema), false);

void main() {
  group('api-class-property-correct', () {
    test('simple', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectClass), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 2);
      expect(parser.apiSchemas['CorrectClass'], apiSchema);
      expect(parser.apiSchemas['SomeClass'], isNotNull);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectClass',
        'type': 'object',
        'properties': {
          'aClass': {r'$ref': 'SomeClass'},
          'anotherName': {
            r'$ref': 'SomeClass',
            'description': 'Description of a Class.'
          },
          'aRequiredClass': {r'$ref': 'SomeClass', 'required': true},
          'anOptionalClass': {r'$ref': 'SomeClass'},
          'aFullClass': {
            r'$ref': 'SomeClass',
            'description': 'Description of a Class.',
            'required': true
          }
        }
      };
      expect(json, expectedJson);
    });
  });

  group('api-class-property-wrong', () {
    test('simple', () {
      var parser = new ApiParser();
      parser.parseSchema(reflectClass(WrongClass), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongClass: aClassWithDefault: Invalid property annotation. '
            'Property of type SomeClass does not support the ApiProperty '
            'field: defaultValue'),
        new ApiConfigError(
            'WrongClass: aClassWithMinMax: Invalid property annotation. '
            'Property of type SomeClass does not support the ApiProperty '
            'field: minValue'),
        new ApiConfigError(
            'WrongClass: aClassWithMinMax: Invalid property annotation. '
            'Property of type SomeClass does not support the ApiProperty '
            'field: maxValue'),
        new ApiConfigError(
            'WrongClass: aClassWithFormat: Invalid property annotation. '
            'Property of type SomeClass does not support the ApiProperty '
            'field: format'),
        new ApiConfigError(
            'WrongClass: aClassWithEnumValues: Invalid property annotation. '
            'Property of type SomeClass does not support the ApiProperty '
            'field: values')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
