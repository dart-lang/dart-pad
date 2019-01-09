// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library messages2;

// Simple message class used with the GET method api tests.
// More elaborate schema testing is done in the api_schema_test.dart file.
class SimpleMessage {
  String aString;
  int anInt;
  bool aBool;
}

// This is used to detect a name conflict between two different class in
// different libraries.
class TestMessage2 {
  int count2;
}

// Schema which conflicts with similar named schema class from another library.
// Specifically api_schema_tests.WrongConflictingWithOther in
// test/src/parser/api_schema_test.dart.
class WrongConflictingWithOther {
  int anInt;
}
