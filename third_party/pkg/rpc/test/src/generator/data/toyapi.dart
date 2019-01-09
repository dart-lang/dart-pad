// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library toyapi;

import 'dart:io';

import 'package:rpc/rpc.dart';
import 'dart:async';

class ToyResponse {
  String result;
  ToyResponse();
}

class ToyResourceResponse {
  String result;
  ToyResourceResponse();
}

class NestedResponse {
  String nestedResult;
  NestedResponse();
}

class ToyMapResponse {
  String result;
  Map<String, NestedResponse> mapResult;

  ToyMapResponse();
}

class ToyRequest {
  @ApiProperty(required: true)
  String name;

  @ApiProperty(defaultValue: 1000)
  int age;
}

class ToyAgeRequest {
  @ApiProperty(defaultValue: 1000)
  int age;
}

@ApiClass(version: '0.1')
class ToyApi {
  ToyApi();

  @ApiResource()
  final ToyCompute compute = new ToyCompute();

  @ApiResource()
  final ToyStorage storage = new ToyStorage();

  @ApiMethod(path: 'noop')
  VoidMessage noop() {
    return null;
  }

  @ApiMethod(path: 'failing')
  VoidMessage failing() {
    throw new RpcError(
        HttpStatus.notImplemented, 'Not Implemented', 'I like to fail!');
  }

  @ApiMethod(path: 'hello')
  ToyResponse hello() {
    return new ToyResponse()..result = 'Hello there!';
  }

  // Clients calling this method will all receive an Internal Server Error
  // as it is not allowed for a method to return null when its declared return
  // type is not VoidMessage.
  @ApiMethod(path: 'helloReturnNull')
  ToyResponse helloReturnNull() {
    return null;
  }

  @ApiMethod(path: 'hello/{name}/age/{age}')
  ToyResponse helloNameAge(String name, int age) {
    return new ToyResponse()..result = 'Hello ${name} of age ${age}!';
  }

  @ApiMethod(path: 'hero/{name}/{isHero}')
  ToyResponse helloHeroWithBoolean(String name, bool isHero,
      {bool fromComics}) {
    String isHeroString;
    if (isHero) {
      isHeroString = "you are a hero";

      if (fromComics != null && fromComics) {
        isHeroString = "${isHeroString} from comics";
      }
    } else {
      isHeroString = "you are not a hero";
    }
    String response = "Hello ${name} ${isHeroString}";
    return new ToyResponse()..result = response;
  }

  @ApiMethod(path: 'helloPost', method: 'POST')
  ToyResponse helloPost(ToyRequest request) {
    return new ToyResponse()
      ..result = 'Hello ${request.name} of age ${request.age}!';
  }

  @ApiMethod(path: 'helloPostWithAsync', method: 'POST')
  Future<ToyResponse> helloPostWithAsync(ToyRequest request) async {
    int delayInSeconds = 5;
    await new Future.delayed(new Duration(seconds: delayInSeconds));
    return new ToyResponse()
      ..result =
          'I waited ${delayInSeconds} seconds to say: Hello ${request.name} of age ${request.age}!';
  }

  @ApiMethod(path: 'helloVoid', method: 'POST')
  ToyResponse helloVoid(VoidMessage request) {
    return new ToyResponse()..result = 'Hello Mr. Void!';
  }

  @ApiMethod(path: 'helloPost/{name}', method: 'POST')
  ToyResponse helloNamePostAge(String name, ToyAgeRequest request) {
    // Use the invocation context to change the response's status code.
    // Can also be used to pass response headers and look at the HTTP requests
    // headers, cookies, and url.
    context.responseStatusCode = HttpStatus.created;
    return new ToyResponse()..result = 'Hello ${name} of age ${request.age}!';
  }

  @ApiMethod(path: 'helloNestedMap')
  ToyMapResponse helloNestedMap() {
    var map = {
      'bar': new NestedResponse()..nestedResult = 'somethingNested',
      'var': new NestedResponse()..nestedResult = 'someotherNested'
    };
    return new ToyMapResponse()
      ..result = 'foo'
      ..mapResult = map;
  }

  @ApiMethod(path: 'helloQuery/{name}')
  ToyResponse helloNameQueryAgeFoo(String name, {String foo, int age}) {
    return new ToyResponse()..result = 'Hello $name of age $age with $foo!';
  }

  @ApiMethod(path: 'reverseList', method: 'POST')
  List<String> reverseList(List<String> request) {
    return request.reversed.toList();
  }

  @ApiMethod(path: 'helloMap', method: 'POST')
  Map<String, int> helloMap(Map<String, int> request) {
    request['hello'] = 42;
    return request;
  }

  @ApiMethod(path: 'helloNestedMapMap', method: 'POST')
  Map<String, Map<String, bool>> helloNestedMapMap(
      Map<String, Map<String, int>> request) {
    return null;
  }

  @ApiMethod(path: 'helloNestedListList', method: 'POST')
  List<List<String>> helloNestedListList(List<List<int>> request) {
    return null;
  }

  @ApiMethod(path: 'helloNestedMapListMap', method: 'POST')
  Map<String, List<Map<String, bool>>> helloNestedMapListMap(
      Map<String, List<Map<String, int>>> request) {
    return null;
  }

  @ApiMethod(path: 'helloNestedListMapList', method: 'POST')
  List<Map<String, List<String>>> helloNestedListMapList(
      List<Map<String, List<int>>> request) {
    return null;
  }

  @ApiMethod(path: 'helloListOfClass', method: 'POST')
  Map<String, ToyResponse> helloListOfClass(List<ToyRequest> request) {
    var key, value;
    if (request == null || request.isEmpty) {
      key = 'John Doe';
      value = 42;
    } else {
      key = request.first.name;
      value = request.first.age;
    }
    return {key: new ToyResponse()..result = value.toString()};
  }

  @ApiMethod(path: 'helloListOfListOfClass', method: 'POST')
  Map<String, ToyResponse> helloListOfListOfClass(
      List<List<ToyRequest>> request) {
    var key, value;
    if (request == null ||
        request.isEmpty ||
        request.first == null ||
        request.first.isEmpty) {
      key = 'John Doe';
      value = 42;
    } else {
      key = request.first.first.name;
      value = request.first.first.age;
    }
    return {key: new ToyResponse()..result = value.toString()};
  }
}

class ToyCompute {
  @ApiMethod(path: 'toyresource/{resource}/compute/{compute}')
  ToyResourceResponse get(String resource, String compute) {
    return new ToyResourceResponse()
      ..result = 'I am the compute: $compute of resource: $resource';
  }
}

class ToyStorage {
  @ApiMethod(path: 'toyresource/{resource}/storage/{storage}')
  ToyResourceResponse get(String resource, String storage) {
    return new ToyResourceResponse()
      ..result = 'I am the storage: $storage of resource: $resource';
  }
}
