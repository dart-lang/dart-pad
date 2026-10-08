// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Whether [type] represents a JS interop value, including generic wrappers.
bool isJsInteropType(DartType? type) => _isJsInteropType(type, {});

bool _isJsInteropType(DartType? type, Set<DartType> visited) {
  if (type == null || !visited.add(type)) return false;
  if (type is TypeParameterType) return _isJsInteropType(type.bound, visited);
  if (type is! InterfaceType) return false;
  final element = type.element;
  if (element is ExtensionTypeElement) {
    final uri = element.library.uri.toString();
    // JS annotations and exceptions in dart:js_interop are ordinary Dart classes.
    if (uri == 'dart:js_interop' || uri == 'dart:_js_types') return true;
    // Looking up the getter on the instantiated type substitutes its arguments.
    // Erasing all extension types would also erase the JS type we need to detect.
    final name = element.representation.name;
    if (name != null && _isJsInteropType(type.getGetter(name)?.returnType, visited)) return true;
  }
  return type.allSupertypes.any((supertype) => _isJsInteropType(supertype, visited));
}
