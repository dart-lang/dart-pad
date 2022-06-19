// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart' show IterableExtension;
import 'package:mdc_web/mdc_web.dart';

import 'elements.dart';

/// Implementation of [TabController] for usage with mdc_web tabs.
class MaterialTabController extends TabController {
  final MDCTabBar tabBar;
  MaterialTabController(this.tabBar);

  @override
  Future<void> selectTab(String tabName) async {
    final idx = tabs.indexWhere((t) => t.name == tabName);
    final tab = tabs[idx];

    tabBar.activateTab(idx);

    for (final t in tabs) {
      t.toggleAttr('aria-selected', t.name == tab.name);
    }

    super.selectTab(tabName);
  }

  void setTabVisibility(String tabName, bool visible) {
    tabs
        .firstWhereOrNull((t) => t.name == tabName)
        ?.toggleAttr('hidden', !visible);
  }
}
