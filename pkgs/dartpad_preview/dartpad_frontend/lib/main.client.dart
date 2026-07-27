// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The entrypoint for the **client** app.
///
/// This file is compiled to javascript and executed on the client when loading the page.
library;

// Client-specific Jaspr import.
import 'package:jaspr/client.dart';
// Imports the [App] component.
// ignore: jaspr_lints/unsafe_imports  //TODO(schultek): possible bug in jaspr lints
import 'app.dart';

void main() {
  // Attaches the [App] component to the <body> of the page.
  runApp(const App());
}
