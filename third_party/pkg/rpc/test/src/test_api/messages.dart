// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of test_api;

class RecursiveMessage1 {
  String message;
  RecursiveMessage1 item;
}

class RecursiveMessage2 {
  String message;
  RecursiveMessage3 item;
}

class RecursiveMessage3 {
  String message;
  RecursiveMessage2 item;
}

class TestMessage1 {
  int count;
  String message;
  double value;
  bool check;
  DateTime date;
  List<String> messages;
  TestMessage2 submessage;
  List<TestMessage2> submessages;

  @ApiProperty(
      values: const {'test1': 'test1', 'test2': 'test2', 'test3': 'test3'})
  String enumValue;

  @ApiProperty(defaultValue: 10)
  int defaultValue;

  @ApiProperty(minValue: 10, maxValue: 100)
  int limit;

  TestMessage1();
}

class TestMessage2 {
  int count;
}

class TestMessage3 {
  @ApiProperty(format: 'int64')
  BigInt count64;

  @ApiProperty(format: 'uint64')
  BigInt count64u;

  @ApiProperty(format: 'int32')
  int count32;

  @ApiProperty(format: 'uint32')
  int count32u;
}

class TestMessage4 {
  @ApiProperty(required: true)
  int requiredValue;

  int count;
}

class TestMessage5 {
  @ApiProperty(name: 'myStrings')
  List<String> listOfStrings;

  List<TestMessage2> listOfObjects;

  Map<String, String> mapStringToString;

  Map<String, TestMessage2> mapStringToObject;
}

class WrongSchema1 {
  WrongSchema1.myConstructor();
}

// WrongSchema2 refers to two different classes with the same name, but residing
// in different libraries. This is not allowed.
class WrongSchema2 {
  TestMessage2 firstTestMessage2;
  messages2.TestMessage2 secondTestMessage2;
}

// WrongSchema3 refers indirectly (nesting) to two different classes with the
// same name, but residing in different libraries. This is not allowed.
class WrongSchema3 {
  TestMessage2 firstTestMessage2;
  NestedSchema nestedSchemaWithOtherTestMessage2;
}

class NestedSchema {
  messages2.TestMessage2 otherTestMessage2;
}
