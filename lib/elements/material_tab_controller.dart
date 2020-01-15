// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_pad/elements/elements.dart';
import 'package:mdc_web/mdc_web.dart';

/// Implementation of [TabController] for usage with mdc_web tabs.
class MaterialTabController extends TabController {
  final MDCTabBar tabBar;
  MaterialTabController(this.tabBar);

  @override
  Future selectTab(String tabName) async {
    var tab = tabs.firstWhere((t) => t.name == tabName);
    var idx = tabs.indexOf(tab);

    tabBar.activateTab(idx);

    for (var t in tabs) {
      t.toggleAttr('aria-selected', t == tab);
    }

    super.selectTab(tabName);
  }

  void setTabVisibility(String tabName, bool visible) {
    tabs
        .firstWhere((t) => t.name == tabName, orElse: () => null)
        ?.toggleAttr('hidden', !visible);
  }
}
