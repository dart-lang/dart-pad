// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library route.test_mocks;

import 'dart:html';
import 'package:mockito/mockito.dart';
import 'package:route_hierarchical/client.dart';

class MockWindow extends Mock implements Window {
  final history = MockHistory();
  final location = MockLocation();
  final document = MockDocument();
}

class MockHistory extends Mock implements History {}

class MockLocation extends Mock implements Location {}

class MockDocument extends Mock implements HtmlDocument {}

class MockMouseEvent extends Mock implements MouseEvent {}

class MockRouter extends Mock implements Router {}
