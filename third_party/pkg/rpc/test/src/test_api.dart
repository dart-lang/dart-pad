// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test_api;

import 'dart:async';

import 'package:rpc/rpc.dart';
import 'test_api/messages2.dart' as messages2;

part 'test_api/messages.dart';

class WrongMethods {
  @ApiMethod()
  void missingAnnotations1() {}

  @ApiMethod(name: 'test1')
  void missingAnnotations2() {}

  @ApiMethod(path: 'test2')
  void missingAnnotations3() {}

  @ApiMethod(name: 'test3', method: 'GET', path: 'test3')
  VoidMessage wrongMethodParameter(VoidMessage _) {
    return null;
  }

  @ApiMethod(name: 'test4', method: 'GET', path: 'test4')
  VoidMessage wrongPathAnnotation(String test) {
    return null;
  }

  @ApiMethod(name: 'test5', method: 'GET', path: 'test5')
  String wrongResponseType1() {
    return '';
  }

  @ApiMethod(name: 'test6', method: 'GET', path: 'test6')
  bool wrongResponseType2() {
    return true;
  }

  @ApiMethod(name: 'test7', method: 'GET', path: 'test7')
  Future<bool> wrongFutureResponse() {
    return new Future.value(true);
  }

  @ApiMethod(name: 'test8', method: 'GET', path: 'test8')
  Future genericFutureResponse() {
    return new Future.value(true);
  }

  @ApiMethod(name: 'test9', method: 'GET', path: 'test9/{id}')
  VoidMessage missingPathParam1() {
    return null;
  }

  @ApiMethod(name: 'test10', method: 'POST', path: 'test10/{id}')
  VoidMessage missingPathParam2(TestMessage1 request) {
    return null;
  }

  @ApiMethod(name: 'test11', method: 'POST', path: 'test11')
  void voidResponse(VoidMessage _) {}

  @ApiMethod(name: 'test12', method: 'POST', path: 'test12')
  VoidMessage noRequest1() {
    return null;
  }

  @ApiMethod(name: 'test13', method: 'POST', path: 'test13/{id}')
  VoidMessage noRequest2(String id) {
    return null;
  }

  @ApiMethod(name: 'test14', method: 'POST', path: 'test14')
  VoidMessage genericRequest(request) {
    return null;
  }

  @ApiMethod(name: 'test15', method: 'GET', path: 'test15/{wrong')
  VoidMessage invalidPath1() {
    return null;
  }

  @ApiMethod(name: 'test16', method: 'GET', path: 'test16/wrong}')
  VoidMessage invalidPath2() {
    return null;
  }
}

@ApiClass(version: 'v1')
class Recursive {
  @ApiMethod(name: 'test1', method: 'POST', path: 'test1')
  VoidMessage resursiveMethod1(RecursiveMessage1 request) {
    return null;
  }

  @ApiMethod(name: 'test2', method: 'POST', path: 'test2')
  VoidMessage resursiveMethod2(RecursiveMessage2 request) {
    return null;
  }
}

@ApiClass(version: 'v1')
class CorrectSimple {
  final String _foo = 'ffo';

  final CorrectMethods _cm = new CorrectMethods();

  CorrectMethods _cmNonFinal = new CorrectMethods();

  @ApiMethod(path: 'test1/{path}')
  VoidMessage simple1(String path) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'test2')
  TestMessage1 simple2(TestMessage1 request) {
    return null;
  }

  // public method which uses private members
  // eliminates analyzer warning about unused private members
  throwAwayPrivateUsage() => [_foo, _cm, _cmNonFinal];
}

@ApiClass(name: 'correct', version: 'v1')
class CorrectMethods {
  @ApiMethod(name: 'test1', path: 'test1')
  VoidMessage method1() {
    return null;
  }

  @ApiMethod(name: 'test2', path: 'test2')
  TestMessage1 method2() {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test3', path: 'test3/{count}')
  TestMessage1 method3(String count) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test4', path: 'test4/{count}/{more}')
  TestMessage1 method4(String count, String more) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test5', path: 'test5/{count}/some/{more}')
  TestMessage1 method5(String count, String more) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test6', method: 'POST', path: 'test6')
  TestMessage1 method6(VoidMessage _) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test7', method: 'POST', path: 'test7')
  VoidMessage method7(TestMessage1 request) {
    return null;
  }

  @ApiMethod(name: 'test8', method: 'POST', path: 'test8')
  TestMessage1 method8(TestMessage1 request) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test9', method: 'POST', path: 'test9/{count}')
  TestMessage1 method9(String count, VoidMessage _) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test10', method: 'POST', path: 'test10/{count}')
  TestMessage1 method10(String count, TestMessage1 request) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test11', method: 'POST', path: 'test11/{count}')
  VoidMessage method11(String count, TestMessage1 request) {
    return null;
  }

  @ApiMethod(name: 'test12', method: 'POST', path: 'test12')
  Future<TestMessage1> method12(VoidMessage _) {
    return new Future.value(new TestMessage1());
  }

  @ApiMethod(name: 'test13', method: 'POST', path: 'test13')
  Future<VoidMessage> method13(VoidMessage _) {
    return new Future.value(new VoidMessage());
  }

  @ApiMethod(name: 'test14', method: 'POST', path: 'test14/{count}/bar')
  VoidMessage method14(String count, TestMessage1 request) {
    return null;
  }

  @ApiMethod(name: 'test15', method: 'POST', path: 'test15/{count}')
  TestMessage1 method15(int count, VoidMessage _) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test16', method: 'POST', path: 'test16/{count}')
  TestMessage1 method16(int count, TestMessage1 request) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test17', method: 'POST', path: 'test17/{count}/bar')
  TestMessage1 method17(int count, TestMessage1 request) {
    return new TestMessage1();
  }
}

class NoAnnotation {}

@ApiClass()
class NoVersion {}

@ApiClass(name: 'Tester', version: 'v1test')
class Tester {}

@ApiClass(version: 'v1test')
class TesterWithOneResource {
  @ApiResource()
  final SomeResource someResource = new SomeResource();
}

@ApiClass(version: 'v1test')
class TesterWithTwoResources {
  @ApiResource()
  final SomeResource someResource = new SomeResource();

  @ApiResource(name: 'nice_name')
  final NamedResource namedResource = new NamedResource();
}

@ApiClass(version: 'v1test')
class TesterWithNestedResources {
  @ApiResource()
  final ResourceWithNested resourceWithNested = new ResourceWithNested();
}

@ApiClass(version: 'v1test')
class TesterWithDuplicateResourceNames {
  @ApiResource()
  final SomeResource someResource = new SomeResource();

  @ApiResource(name: 'someResource')
  final NamedResource namedResource = new NamedResource();
}

@ApiClass(version: 'v1test')
class TesterWithMultipleResourceAnnotations {
  @ApiResource()
  @ApiResource()
  final SomeResource someResource = new SomeResource();
}

@ApiClass(version: 'v1test')
class MultipleMethodAnnotations {
  @ApiMethod(path: 'multi')
  @ApiMethod(path: 'multi2')
  VoidMessage multiAnnotations() {
    return null;
  }
}

class SomeResource {
  @ApiMethod(path: 'someResourceMethod')
  VoidMessage method1() {
    return null;
  }
}

class NamedResource {
  @ApiMethod(path: 'namedResourceMethod')
  VoidMessage method1() {
    return null;
  }
}

class ResourceWithNested {
  @ApiResource()
  NestedResource nestedResource = new NestedResource();
}

class NestedResource {
  @ApiMethod(path: 'nestedResourceMethod')
  VoidMessage method1() {
    return null;
  }
}

@ApiClass(version: 'v1test')
class CorrectQueryParameterTester {
  @ApiMethod(path: 'query1')
  VoidMessage query1({String name}) {
    return null;
  }

  @ApiMethod(path: 'query2/{pathParam}')
  VoidMessage query2(String pathParam, {String queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query3')
  VoidMessage query3({String qp1, String qp2}) {
    return null;
  }

  @ApiMethod(path: 'query4')
  VoidMessage query4({int qp}) {
    return null;
  }

  @ApiMethod(path: 'query5')
  VoidMessage query5({String qp1, int qp2}) {
    return null;
  }

  @ApiMethod(path: 'query6')
  VoidMessage query6({int qp1, String qp2}) {
    return null;
  }

  @ApiMethod(path: 'query7')
  VoidMessage query7({int qp1, int qp2}) {
    return null;
  }
}

@ApiClass(version: 'v1test')
class WrongQueryParameterTester {
  @ApiMethod(path: 'query1')
  VoidMessage query1(String path) {
    return null;
  }

  @ApiMethod(path: 'query2/{queryParam}')
  VoidMessage query2(String pathParam, {String queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query3')
  VoidMessage query3({queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query4/{queryParam}')
  VoidMessage query4({String queryParam}) {
    return null;
  }

  @ApiMethod(path: 'query5')
  VoidMessage query5([String queryParam]) {
    return null;
  }
}
