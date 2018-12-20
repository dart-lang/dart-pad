// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_property_double_tests;

import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/utils.dart';
import 'package:rpc/src/discovery/config.dart' as discovery;
import 'package:test/test.dart';

class CorrectDouble {
  double aDouble;

  @ApiProperty(name: 'anotherName', description: 'Description of a Double.')
  double aNamedDouble;

  @ApiProperty(defaultValue: 4.2)
  double aDoubleWithDefault;

  @ApiProperty(format: 'double')
  double aDoubleWithFormat1;

  @ApiProperty(format: 'float')
  double aDoubleWithFormat2;

  @ApiProperty(defaultValue: -1e308)
  double aDoubleWithVerySmallDefault;

  @ApiProperty(defaultValue: 1e308)
  double aDoubleWithVeryLargeDefault;

  @ApiProperty(format: 'float', defaultValue: SMALLEST_FLOAT)
  double aFloatWithVerySmallDefault;

  @ApiProperty(format: 'float', defaultValue: LARGEST_FLOAT)
  double aFloatWithVeryLargeDefault;

  @ApiProperty(required: true)
  double aRequiredDouble;

  @ApiProperty(required: false)
  double anOptionalDouble;

  @ApiProperty(ignore: true)
  double ignored;
}

class WrongDouble {
  @ApiProperty(minValue: 0, maxValue: 1)
  double aDoubleWithMinMax;

  @ApiProperty(format: 'int32')
  double aDoubleWithIntFormat;

  @ApiProperty(format: 'foo')
  double aDoubleWithInvalidFormat;

  @ApiProperty(values: const {'enumKey': 'enumValue'})
  double aDoubleWithEnumValues;

  @ApiProperty(defaultValue: -2.0e308)
  double aDoubleWithTooSmallDefault;

  @ApiProperty(defaultValue: 2.0e+309)
  double aDoubleWithTooLargeDefault;

  @ApiProperty(format: 'float', defaultValue: SMALLEST_FLOAT * 10)
  double aFloatWithTooSmallDefault;

  @ApiProperty(format: 'float', defaultValue: LARGEST_FLOAT * 10)
  double aFloatWithTooLargeDefault;
}

final ApiConfigSchema jsonSchema =
    new ApiParser().parseSchema(reflectClass(discovery.JsonSchema), false);

void main() {
  group('api-double-property-correct', () {
    test('simple', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectDouble), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 1);
      expect(parser.apiSchemas['CorrectDouble'], apiSchema);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectDouble',
        'type': 'object',
        'properties': {
          'aDouble': {'type': 'number', 'format': 'double'},
          'anotherName': {
            'type': 'number',
            'description': 'Description of a Double.',
            'format': 'double'
          },
          'aDoubleWithDefault': {
            'type': 'number',
            'default': '4.2',
            'format': 'double'
          },
          'aDoubleWithFormat1': {'type': 'number', 'format': 'double'},
          'aDoubleWithFormat2': {'type': 'number', 'format': 'float'},
          'aDoubleWithVerySmallDefault': {
            'type': 'number',
            'default': '-1e+308',
            'format': 'double'
          },
          'aDoubleWithVeryLargeDefault': {
            'type': 'number',
            'default': '1e+308',
            'format': 'double'
          },
          'aFloatWithVerySmallDefault': {
            'type': 'number',
            'default': '-3.4e+38',
            'format': 'float'
          },
          'aFloatWithVeryLargeDefault': {
            'type': 'number',
            'default': '3.4e+38',
            'format': 'float'
          },
          'aRequiredDouble': {
            'type': 'number',
            'required': true,
            'format': 'double'
          },
          'anOptionalDouble': {'type': 'number', 'format': 'double'}
        }
      };
      expect(json, expectedJson);
    });
  });

  group('api-double-property-wrong', () {
    test('simple', () {
      var parser = new ApiParser();
      parser.parseSchema(reflectClass(WrongDouble), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongDouble: aDoubleWithMinMax: Invalid property annotation. '
            'Property of type double does not support the ApiProperty field: '
            'minValue'),
        new ApiConfigError(
            'WrongDouble: aDoubleWithMinMax: Invalid property annotation. '
            'Property of type double does not support the ApiProperty field: '
            'maxValue'),
        new ApiConfigError(
            'WrongDouble: aDoubleWithIntFormat: Invalid double variant: '
            '\'int32\'. Must be either \'double\' or \'float\'.'),
        new ApiConfigError(
            'WrongDouble: aDoubleWithInvalidFormat: Invalid double variant: '
            '\'foo\'. Must be either \'double\' or \'float\'.'),
        new ApiConfigError(
            'WrongDouble: aDoubleWithEnumValues: Invalid property annotation. '
            'Property of type double does not support the ApiProperty field: '
            'values'),
        new ApiConfigError(
            'WrongDouble: aDoubleWithTooSmallDefault: Default value of: '
            '-Infinity with format: \'double\', must be in the range: '
            '[-1.7976931348623157e+308, 1.7976931348623157e+308]'),
        new ApiConfigError(
            'WrongDouble: aDoubleWithTooLargeDefault: Default value of: '
            'Infinity with format: \'double\', must be in the range: '
            '[-1.7976931348623157e+308, 1.7976931348623157e+308]'),
        new ApiConfigError(
            'WrongDouble: aFloatWithTooSmallDefault: Default value of: '
            '-3.4e+39 with format: \'float\', must be in the range: '
            '[-3.4e+38, 3.4e+38]'),
        new ApiConfigError(
            'WrongDouble: aFloatWithTooLargeDefault: Default value of: '
            '3.4e+39 with format: \'float\', must be in the range: '
            '[-3.4e+38, 3.4e+38]')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
