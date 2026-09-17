// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../app_styles.dart';
import 'project_persistence_state.dart';

final class PersistenceNoticeBanner extends StatelessComponent {
  const PersistenceNoticeBanner({required this.notice, super.key});

  final PersistenceNotice notice;

  @override
  Component build(BuildContext context) => div(
    classes: 'persistence-notice',
    attributes: const {'role': 'status'},
    [
      .text(switch (notice) {
        ProjectHistoryUnavailable() => 'Your saved projects could not be loaded. Local saving is paused.',
        ProjectSaveFailed() =>
          'Your work could not be saved in this browser. Keep this tab open and copy your changes before leaving.',
        RestoredWithDifferentSdk(:final sdk) =>
          'Your previous SDK is no longer available. Your work was restored with ${sdk.displayName}.',
      }),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.persistence-notice').styles(
      padding: .symmetric(vertical: 8.px, horizontal: 16.px),
      color: colorOnSurface,
      fontSize: 13.px,
      backgroundColor: colorContainer,
    ),
  ];
}
