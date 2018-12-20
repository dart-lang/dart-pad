// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_property_bool_tests;

import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/discovery/config.dart' as discovery;
import 'package:test/test.dart';

class CorrectBool {
  bool aBool;

  @ApiProperty(name: 'anotherName', description: 'Description of a bool.')
  bool aNamedBool;

  @ApiProperty(defaultValue: true)
  bool aBoolWithDefault;

  @ApiProperty(required: true)
  bool aRequiredBool;

  @ApiProperty(ignore: true)
  bool ignored;
}

class WrongBool {
  @ApiProperty(minValue: 0, maxValue: 1)
  bool aBoolWithMinMax;

  @ApiProperty(format: 'int32')
  bool aBoolWithFormat;

  @ApiProperty(values: const {'enumKey': 'enumValue'})
  bool aBoolWithEnumValues;
}

final ApiConfigSchema jsonSchema =
    new ApiParser().parseSchema(reflectClass(discovery.JsonSchema), false);

void main() {
  group('api-bool-property-correct', () {
    test('simple', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectBool), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 1);
      expect(parser.apiSchemas['CorrectBool'], apiSchema);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectBool',
        'type': 'object',
        'properties': {
          'aBool': {'type': 'boolean'},
          'anotherName': {
            'type': 'boolean',
            'description': 'Description of a bool.'
          },
          'aBoolWithDefault': {'type': 'boolean', 'default': 'true'},
          'aRequiredBool': {'type': 'boolean', 'required': true}
        }
      };
      expect(json, expectedJson);
    });
  });

  group('api-bool-property-wrong', () {
    test('simple', () {
      var parser = new ApiParser();

      parser.parseSchema(reflectClass(WrongBool), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongBool: aBoolWithMinMax: Invalid property annotation. Property '
            'of type bool does not support the ApiProperty field: minValue'),
        new ApiConfigError(
            'WrongBool: aBoolWithMinMax: Invalid property annotation. Property '
            'of type bool does not support the ApiProperty field: maxValue'),
        new ApiConfigError(
            'WrongBool: aBoolWithFormat: Invalid property annotation. Property '
            'of type bool does not support the ApiProperty field: format'),
        new ApiConfigError(
            'WrongBool: aBoolWithEnumValues: Invalid property annotation. '
            'Property of type bool does not support the ApiProperty field: '
            'values')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
