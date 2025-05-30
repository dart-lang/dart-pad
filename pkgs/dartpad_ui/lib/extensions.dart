// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension GoRouteHelpers on GoRouter {
  /// Calls go() with the existing query parameters and replaces
  /// [param] with [value]. If [value] is null, the parameter
  /// is removed.
  void replaceQueryParam(String param, String? value) {
    final currentUri = routeInformationProvider.value.uri;
    final newQueryParameters = {...currentUri.queryParameters};

    if (value == null) {
      newQueryParameters.remove(param);
    } else {
      newQueryParameters[param] = value;
    }

    go(currentUri.replace(queryParameters: newQueryParameters).toString());
  }
}

extension MenuControllerExtension on MenuController {
  void toggle() {
    if (isOpen) {
      close();
    } else {
      open();
    }
  }
}
