// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_schema_tests;

import 'dart:collection';
import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/discovery/config.dart' as discovery;
import 'package:test/test.dart';

import '../test_api/messages2.dart' as messages2;

class CorrectSimple {
  String aString;
  int anInt;
  bool aBool;
  double aDouble;
  DateTime aDate;
}

class CorrectModifiers {
  // Final fields do become part of the message.
  final String aString = 'foo';
  final int anInt = 42;
  final bool aBool = true;
  final double aDouble = 4.2;
  final DateTime aDate = new DateTime(2015);

  // Static and static const fields do _not_ become part of the message.
  static int aStaticInt = 2;
  static const String aConstString = 'constantFoo';

  // Private fields also do _not_ become part of the message.
  String _aString;
  int _anInt;
  bool _aBool;
  double _aDouble;
  DateTime _aDate;

  // public method which uses private members
  // eliminates analyzer warning about unused private members
  throwAwayPrivateUsage() => [_aString, _anInt, _aBool, _aDouble, _aDate];
}

class CorrectContainers {
  List<String> aStringList;
  List<int> anIntList;
  List<bool> aBoolList;
  List<double> aDoubleList;
  List<DateTime> aDateList;
  List<Nested> aNestedList;

  Map<String, String> aStringMap;
  Map<String, int> anIntMap;
  Map<String, bool> aBoolMap;
  Map<String, double> aDoubleMap;
  Map<String, DateTime> aDateMap;
  Map<String, Nested> aNestedMap;
}

class CorrectNested {
  int anInt;
  Nested aNestedClass;
}

class Nested {
  String aString;
}

class CorrectRecursive {
  String message;
  CorrectRecursive item;
}

class CorrectIndirectRecursive {
  String message;
  IndirectRecursive item;
}

class IndirectRecursive {
  String message;
  CorrectIndirectRecursive item;
}

class WrongSimple {
  dynamic aDynamic;
  var anUntyped;

  // The 'num' type is not supported. Use either 'int' or 'double'.
  num aNumber;

  WrongSimple.named();
}

// Set and Queue are not supported collections.
class WrongContainers {
  Set<String> aStringSet;
  Set<int> anIntSet;
  Set<bool> aBoolSet;
  Set<double> aDoubleSet;
  Set<DateTime> aDateSet;
  Set<Nested> aNestedSet;

  Queue<String> aStringQueue;
  Queue<int> anIntQueue;
  Queue<bool> aBoolQueue;
  Queue<double> aDoubleQueue;
  Queue<DateTime> aDateQueue;
  Queue<Nested> aNestedQueue;

  Map<int, String> aMapWithIntKey;
  Map<dynamic, String> aMapWithDynamicKey;
  Map<Nested, String> aMapWithNestedKey;
}

// Schema which conflicts with similar named schema class from another library.
// Specifically messages2.WrongConflictingWithOther in
// test/src/test_api/messages2.dart.
class WrongConflictingWithOther {
  String aString;
}

@ApiClass(version: 'v1')
class WrongConflictingApi {
  @ApiMethod(method: 'POST', path: 'conflicting1')
  WrongConflictingWithOther conflicting1(WrongConflictingWithOther msg) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'conflicting2')
  messages2.WrongConflictingWithOther conflicting2(
      messages2.WrongConflictingWithOther msg) {
    return null;
  }
}

final ApiConfigSchema jsonSchema =
    new ApiParser().parseSchema(reflectClass(discovery.JsonSchema), false);

void main() {
  group('api-schema-correct', () {
    test('simple', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectSimple), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 1);
      expect(parser.apiSchemas['CorrectSimple'], apiSchema);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectSimple',
        'type': 'object',
        'properties': {
          'aString': {'type': 'string'},
          'anInt': {'type': 'integer', 'format': 'int32'},
          'aBool': {'type': 'boolean'},
          'aDouble': {'type': 'number', 'format': 'double'},
          'aDate': {'type': 'string', 'format': 'date-time'}
        }
      };
      expect(json, expectedJson);
    });

    test('modifiers', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectModifiers), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 1);
      expect(parser.apiSchemas['CorrectModifiers'], apiSchema);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectModifiers',
        'type': 'object',
        'properties': {
          'aString': {'type': 'string'},
          'anInt': {'type': 'integer', 'format': 'int32'},
          'aBool': {'type': 'boolean'},
          'aDouble': {'type': 'number', 'format': 'double'},
          'aDate': {'type': 'string', 'format': 'date-time'}
        }
      };
      expect(json, expectedJson);
    });

    test('containers', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectContainers), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 2);
      expect(parser.apiSchemas['CorrectContainers'], apiSchema);
      expect(parser.apiSchemas['Nested'], isNotNull);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectContainers',
        'type': 'object',
        'properties': {
          'aStringList': {
            'type': 'array',
            'items': {'type': 'string'}
          },
          'anIntList': {
            'type': 'array',
            'items': {'type': 'integer', 'format': 'int32'}
          },
          'aBoolList': {
            'type': 'array',
            'items': {'type': 'boolean'}
          },
          'aDoubleList': {
            'type': 'array',
            'items': {'type': 'number', 'format': 'double'}
          },
          'aDateList': {
            'type': 'array',
            'items': {'type': 'string', 'format': 'date-time'}
          },
          'aNestedList': {
            'type': 'array',
            'items': {r'$ref': 'Nested'}
          },
          'aStringMap': {
            'type': 'object',
            'additionalProperties': {'type': 'string'}
          },
          'anIntMap': {
            'type': 'object',
            'additionalProperties': {'type': 'integer', 'format': 'int32'}
          },
          'aBoolMap': {
            'type': 'object',
            'additionalProperties': {'type': 'boolean'}
          },
          'aDoubleMap': {
            'type': 'object',
            'additionalProperties': {'type': 'number', 'format': 'double'}
          },
          'aDateMap': {
            'type': 'object',
            'additionalProperties': {'type': 'string', 'format': 'date-time'}
          },
          'aNestedMap': {
            'type': 'object',
            'additionalProperties': {r'$ref': 'Nested'}
          }
        }
      };
      expect(json, expectedJson);
    });

    test('nested', () {
      var parser = new ApiParser();
      ApiConfigSchema correctNestedSchema =
          parser.parseSchema(reflectClass(CorrectNested), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 2);
      expect(parser.apiSchemas['CorrectNested'], correctNestedSchema);
      var json = jsonSchema.toResponse(correctNestedSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectNested',
        'type': 'object',
        'properties': {
          'anInt': {'type': 'integer', 'format': 'int32'},
          'aNestedClass': {r'$ref': 'Nested'}
        }
      };
      expect(json, expectedJson);
      // Check the nested class
      var nestedSchema = parser.apiSchemas['Nested'];
      expect(nestedSchema, isNotNull);
      json = jsonSchema.toResponse(nestedSchema.asDiscovery);
      expectedJson = {
        'id': 'Nested',
        'type': 'object',
        'properties': {
          'aString': {'type': 'string'}
        }
      };
      expect(json, expectedJson);
    });

    test('recursive', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectRecursive), true);
      expect(parser.isValid, isTrue);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectRecursive',
        'type': 'object',
        'properties': {
          'message': {'type': 'string'},
          'item': {r'$ref': 'CorrectRecursive'}
        }
      };
      expect(json, expectedJson);
    });

    test('indirect-recursive', () {
      var parser = new ApiParser();
      ApiConfigSchema apiSchema =
          parser.parseSchema(reflectClass(CorrectIndirectRecursive), true);
      expect(parser.isValid, isTrue);
      expect(parser.apiSchemas.length, 2);
      var json = jsonSchema.toResponse(apiSchema.asDiscovery);
      var expectedJson = {
        'id': 'CorrectIndirectRecursive',
        'type': 'object',
        'properties': {
          'message': {'type': 'string'},
          'item': {r'$ref': 'IndirectRecursive'}
        }
      };
      expect(json, expectedJson);
    });
  });

  group('api-schema-wrong', () {
    test('simple', () {
      var parser = new ApiParser();
      parser.parseSchema(reflectClass(WrongSimple), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongSimple: Schema \'WrongSimple\' must have an unnamed '
            'constructor taking no arguments.'),
        new ApiConfigError(
            'WrongSimple: aDynamic: Properties cannot be of type: '
            '\'dynamic\'.'),
        new ApiConfigError(
            'WrongSimple: anUntyped: Properties cannot be of type: '
            '\'dynamic\'.'),
        new ApiConfigError(
            'WrongSimple: aNumber: Unsupported property type: num')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('containers', () {
      var parser = new ApiParser();
      parser.parseSchema(reflectClass(WrongContainers), true);
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongContainers: aStringSet: Unsupported property type: '
            'Set<String>'),
        new ApiConfigError(
            'WrongContainers: anIntSet: Unsupported property type: Set<int>'),
        new ApiConfigError(
            'WrongContainers: aBoolSet: Unsupported property type: Set<bool>'),
        new ApiConfigError(
            'WrongContainers: aDoubleSet: Unsupported property type: '
            'Set<double>'),
        new ApiConfigError(
            'WrongContainers: aDateSet: Unsupported property type: '
            'Set<DateTime>'),
        new ApiConfigError(
            'WrongContainers: aNestedSet: Unsupported property type: '
            'Set<Nested>'),
        new ApiConfigError(
            'WrongContainers: aStringQueue: Unsupported property type: '
            'Queue<String>'),
        new ApiConfigError(
            'WrongContainers: anIntQueue: Unsupported property type: '
            'Queue<int>'),
        new ApiConfigError(
            'WrongContainers: aBoolQueue: Unsupported property type: '
            'Queue<bool>'),
        new ApiConfigError(
            'WrongContainers: aDoubleQueue: Unsupported property type: '
            'Queue<double>'),
        new ApiConfigError(
            'WrongContainers: aDateQueue: Unsupported property type: '
            'Queue<DateTime>'),
        new ApiConfigError(
            'WrongContainers: aNestedQueue: Unsupported property type: '
            'Queue<Nested>'),
        new ApiConfigError(
            'WrongContainers: aMapWithIntKey: Maps must have keys of type '
            '\'String\'.'),
        new ApiConfigError(
            'WrongContainers: aMapWithDynamicKey: Maps must have keys of type '
            '\'String\'.'),
        new ApiConfigError(
            'WrongContainers: aMapWithNestedKey: Maps must have keys of type '
            '\'String\'.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('conflicting-schemas', () {
      var parser = new ApiParser();
      parser.parse(new WrongConflictingApi());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError('WrongConflictingWithOther: Schema '
            '\'messages2.WrongConflictingWithOther\' has a name conflict with '
            '\'api_schema_tests.WrongConflictingWithOther\'.'),
        new ApiConfigError('WrongConflictingWithOther: Schema '
            '\'messages2.WrongConflictingWithOther\' has a name conflict with '
            '\'api_schema_tests.WrongConflictingWithOther\'.')
      ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}
