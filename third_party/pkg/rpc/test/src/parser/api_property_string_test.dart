// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_property_string_tests;

import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/discovery/config.dart' as discovery;
import 'package:test/test.dart';

class CorrectString {
  String aString;

  @ApiProperty(name: 'anotherName', description: 'Description of a String.')
  String aNamedString;

  @ApiProperty(defaultValue: 'foo')
  String aStringWithDefault;

  @ApiProperty(required: true)
  String aRequiredString;

  @ApiProperty(required: false)
  String anOptionalString;

  @ApiProperty(
      name: 'aFullString',
      description: 'Description of a String.',
      required: true,
      defaultValue: 'foo')
  String aStringWithAllAnnotations;

  @ApiProperty(ignore: true)
  String ignored;
}

class WrongString {
  @ApiProperty(minValue: 0, maxValue: 1)
  String aStringWithMinMax;

  @ApiProperty(format: 'int32')
  String aStringWithFormat;
}

final ApiConfigSchema jsonSchema =
    new ApiParser().parseSchema(reflectClass(discovery.JsonSchema), false);

void main() {
  group('api-string-property-correct', () {
    test('simple', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectString), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 1);
      expect(parser.apiSchemas['CorrectString'], apiSchema);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectString',
        'type': 'object',
        'properties': {
          'aString': {'type': 'string'},
          'anotherName': {
            'type': 'string',
            'description': 'Description of a String.'
          },
          'aStringWithDefault': {'type': 'string', 'default': 'foo'},
          'aRequiredString': {'type': 'string', 'required': true},
          'anOptionalString': {'type': 'string'},
          'aFullString': {
            'type': 'string',
            'description': 'Description of a String.',
            'default': 'foo',
            'required': true
          }
        }
      };
      expect(json, expectedJson);
    });
  });

  group('api-string-property-wrong', () {
    test('simple', () {
      var parser = new ApiParser();
      parser.parseSchema(reflectClass(WrongString), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongString: aStringWithMinMax: Invalid property annotation. '
            'Property of type String does not support the ApiProperty field: '
            'minValue'),
        new ApiConfigError(
            'WrongString: aStringWithMinMax: Invalid property annotation. '
            'Property of type String does not support the ApiProperty field: '
            'maxValue'),
        new ApiConfigError(
            'WrongString: aStringWithFormat: Invalid property annotation. '
            'Property of type String does not support the ApiProperty field: '
            'format'),
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
