// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_property_enum_tests;

import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/discovery/config.dart' as discovery;
import 'package:test/test.dart';

class CorrectEnum {
  @ApiProperty(values: const {'foo': 'A Foo', 'bar': 'A Bar'})
  String anEnum;

  @ApiProperty(
      name: 'anotherName',
      description: 'Description of an Enum.',
      values: const {'foo': 'A Foo', 'bar': 'A Bar'})
  String aNamedEnum;

  @ApiProperty(
      values: const {'foo': 'A Foo', 'bar': 'A Bar'}, defaultValue: 'foo')
  String anEnumWithDefault;

  @ApiProperty(values: const {'foo': 'A Foo', 'bar': 'A Bar'}, required: true)
  String aRequiredEnum;

  @ApiProperty(
      name: 'aFullEnum',
      description: 'Description of an Enum.',
      values: const {'foo': 'A Foo', 'bar': 'A Bar'},
      required: true,
      defaultValue: 'bar')
  String anEnumWithAllAnnotations;

  @ApiProperty(values: const {'foo': 'A Foo', 'bar': 'A Bar'}, ignore: true)
  String ignored;
}

class WrongEnum {
  @ApiProperty(
      values: const {'foo': 'A Foo', 'bar': 'A Bar'}, minValue: 0, maxValue: 1)
  String anEnumWithMinMax;

  @ApiProperty(values: const {'foo': 'A Foo', 'bar': 'A Bar'}, format: 'int32')
  String anEnumWithFormat;

  @ApiProperty(
      values: const {'foo': 'A Foo', 'bar': 'A Bar'}, defaultValue: 'baz')
  String anEnumWithIncorrectDefault;
}

final ApiConfigSchema jsonSchema =
    new ApiParser().parseSchema(reflectClass(discovery.JsonSchema), false);

void main() {
  group('api-enum-property-correct', () {
    test('simple', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectEnum), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 1);
      expect(parser.apiSchemas['CorrectEnum'], apiSchema);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectEnum',
        'type': 'object',
        'properties': {
          'anEnum': {
            'type': 'string',
            'enum': ['foo', 'bar'],
            'enumDescriptions': ['A Foo', 'A Bar']
          },
          'anotherName': {
            'type': 'string',
            'description': 'Description of an Enum.',
            'enum': ['foo', 'bar'],
            'enumDescriptions': ['A Foo', 'A Bar']
          },
          'anEnumWithDefault': {
            'type': 'string',
            'default': 'foo',
            'enum': ['foo', 'bar'],
            'enumDescriptions': ['A Foo', 'A Bar']
          },
          'aRequiredEnum': {
            'type': 'string',
            'required': true,
            'enum': ['foo', 'bar'],
            'enumDescriptions': ['A Foo', 'A Bar']
          },
          'aFullEnum': {
            'type': 'string',
            'description': 'Description of an Enum.',
            'default': 'bar',
            'required': true,
            'enum': ['foo', 'bar'],
            'enumDescriptions': ['A Foo', 'A Bar']
          }
        }
      };
      expect(json, expectedJson);
    });
  });

  group('api-enum-property-wrong', () {
    test('simple', () {
      var parser = new ApiParser();
      parser.parseSchema(reflectClass(WrongEnum), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongEnum: anEnumWithMinMax: Invalid property annotation. '
            'Property of type Enum does not support the ApiProperty field: '
            'minValue'),
        new ApiConfigError(
            'WrongEnum: anEnumWithMinMax: Invalid property annotation. '
            'Property of type Enum does not support the ApiProperty field: '
            'maxValue'),
        new ApiConfigError(
            'WrongEnum: anEnumWithFormat: Invalid property annotation. '
            'Property of type Enum does not support the ApiProperty field: '
            'format'),
        new ApiConfigError(
            'WrongEnum: anEnumWithIncorrectDefault: Default value: baz must be '
            'one of the valid enum values: (foo, bar).')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
