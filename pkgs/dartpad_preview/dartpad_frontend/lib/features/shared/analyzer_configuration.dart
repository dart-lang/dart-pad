// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

/// Exposes the analyzer policy fixed at app startup, independently of layout.
final class AnalyzerConfiguration extends InheritedComponent {
  const AnalyzerConfiguration({required this.enabled, required super.child, super.key});

  final bool enabled;

  /// Reads the startup policy without subscribing to changes.
  /// Standalone components default to having analyzer support.
  static bool isEnabledOf(BuildContext context) =>
      (context.getElementForInheritedComponentOfExactType<AnalyzerConfiguration>()?.component as AnalyzerConfiguration?)
          ?.enabled ??
      true;

  @override
  bool updateShouldNotify(covariant AnalyzerConfiguration oldComponent) => false;
}
