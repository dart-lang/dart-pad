// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_property_datetime_tests;

import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/discovery/config.dart' as discovery;
import 'package:test/test.dart';

class CorrectDateTime {
  DateTime aDateTime;

  @ApiProperty(name: 'anotherName', description: 'Description of a DateTime.')
  DateTime aNamedDateTime;

  @ApiProperty(defaultValue: '1969-07-20T20:18:00.000Z')
  DateTime aDateTimeWithDefault;

  @ApiProperty(required: true)
  DateTime aRequiredDateTime;

  @ApiProperty(required: false)
  DateTime anOptionalDateTime;

  @ApiProperty(ignore: true)
  DateTime ignored;
}

class WrongDateTime {
  @ApiProperty(minValue: 0, maxValue: 1)
  DateTime aDateTimeWithMinMax;

  @ApiProperty(format: 'int32')
  DateTime aDateTimeWithIntFormat;

  @ApiProperty(format: 'foo')
  DateTime aDateTimeWithInvalidFormat;

  @ApiProperty(values: const {'enumKey': 'enumValue'})
  DateTime aDateTimeWithEnumValues;

  @ApiProperty(defaultValue: 'incorrect date')
  DateTime aDateTimeWithIncorrectDefault;
}

final ApiConfigSchema jsonSchema =
    new ApiParser().parseSchema(reflectClass(discovery.JsonSchema), false);

void main() {
  group('api-datetime-property-correct', () {
    test('simple', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectDateTime), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 1);
      expect(parser.apiSchemas['CorrectDateTime'], apiSchema);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectDateTime',
        'type': 'object',
        'properties': {
          'aDateTime': {'type': 'string', 'format': 'date-time'},
          'anotherName': {
            'type': 'string',
            'description': 'Description of a DateTime.',
            'format': 'date-time'
          },
          'aDateTimeWithDefault': {
            'type': 'string',
            'default': '1969-07-20T20:18:00.000Z',
            'format': 'date-time'
          },
          'aRequiredDateTime': {
            'type': 'string',
            'required': true,
            'format': 'date-time'
          },
          'anOptionalDateTime': {'type': 'string', 'format': 'date-time'}
        }
      };
      expect(json, expectedJson);
    });
  });

  group('api-datetime-property-wrong', () {
    test('simple', () {
      var parser = new ApiParser();
      parser.parseSchema(reflectClass(WrongDateTime), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongDateTime: aDateTimeWithMinMax: Invalid property annotation. '
            'Property of type DateTime does not support the ApiProperty field: '
            'minValue'),
        new ApiConfigError(
            'WrongDateTime: aDateTimeWithMinMax: Invalid property annotation. '
            'Property of type DateTime does not support the ApiProperty field: '
            'maxValue'),
        new ApiConfigError(
            'WrongDateTime: aDateTimeWithIntFormat: Invalid property '
            'annotation. Property of type DateTime does not support the '
            'ApiProperty field: format'),
        new ApiConfigError(
            'WrongDateTime: aDateTimeWithInvalidFormat: Invalid property '
            'annotation. Property of type DateTime does not support the '
            'ApiProperty field: format'),
        new ApiConfigError(
            'WrongDateTime: aDateTimeWithEnumValues: Invalid property '
            'annotation. Property of type DateTime does not support the '
            'ApiProperty field: values'),
        new ApiConfigError(
            'WrongDateTime: aDateTimeWithIncorrectDefault: Invalid datetime '
            'value \'incorrect date\'. See documentation for DateTime.parse '
            'for format definition.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
