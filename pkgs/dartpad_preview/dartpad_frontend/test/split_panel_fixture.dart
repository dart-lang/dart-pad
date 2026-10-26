// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';

/// Creates a split owner and disposes it after its panel has unmounted.
ValueNotifier<SplitState> createSplitOwner(ClientTester tester, SplitState initialState) {
  final owner = ValueNotifier(initialState);
  addTearDown(() async {
    tester.binding.detachRootComponent();
    await pumpEventQueue();
    owner.dispose();
  });
  return owner;
}

/// Hosts a split with an owner that accepts and writes back requested changes.
Component withSplitOwner(
  ClientTester tester,
  SplitState initialState,
  Component Function(ValueListenable<SplitState> state, ValueChanged<SplitState> onChanged) builder,
) {
  final owner = createSplitOwner(tester, initialState);
  return builder(owner, (value) => owner.value = value);
}
