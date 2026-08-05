// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Displays path-aware Pub actions for an active Pub metadata file.
final class PubspecEditorActions extends StatelessComponent {
  /// Creates the floating Pub actions for [activeFile].
  const PubspecEditorActions({
    required this.activeFile,
    required this.busy,
    required this.onPubGet,
    required this.onPubClean,
    super.key,
  });

  /// The path shown in the active editor tab.
  final String activeFile;

  /// Whether either Pub action is currently running.
  final bool busy;

  /// Runs Pub Get in the supplied workspace-relative directory.
  final Future<void> Function(String path) onPubGet;

  /// Runs Pub Clean in the supplied workspace-relative directory.
  final Future<void> Function(String path) onPubClean;

  @override
  Component build(BuildContext context) {
    final fileName = workspaceContext.basename(activeFile);
    if (fileName != 'pubspec.yaml' && fileName != 'pubspec.lock') {
      return const Component.fragment([]);
    }

    final directory = workspaceContext.dirname(activeFile);
    return div(classes: 'pubspec-editor-actions', [
      _button(
        label: 'Pub get',
        disabled: busy,
        onClick: () => onPubGet(directory),
      ),
      _button(
        label: 'Pub clean',
        disabled: busy,
        onClick: () => onPubClean(directory),
      ),
    ]);
  }

  Component _button({
    required String label,
    required bool disabled,
    required Future<void> Function() onClick,
  }) {
    return button(
      classes: 'pubspec-maintenance-button',
      attributes: {
        'title': label,
        'aria-label': label,
        if (disabled) 'disabled': '',
      },
      onClick: disabled ? null : () => unawaited(onClick()),
      [.text(label)],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.pubspec-editor-actions').styles(
      display: .flex,
      position: .absolute(right: 32.px, bottom: 16.px),
      zIndex: const ZIndex(20),
      alignItems: .center,
      gap: .all(8.px),
    ),
    css('.pubspec-maintenance-button', [
      css('&').styles(
        display: .inlineFlex,
        padding: .symmetric(vertical: 5.px, horizontal: 8.px),
        border: .all(color: const Color('#454545'), width: 1.px),
        radius: .circular(5.px),
        outline: const Outline(style: .none),
        cursor: .pointer,
        justifyContent: .center,
        alignItems: .center,
        color: const Color('#d4d4d4'),
        fontSize: 12.px,
        fontWeight: FontWeight.w500,
        whiteSpace: .noWrap,
        backgroundColor: const Color('#252525'),
      ),
      css('&:not(:disabled):hover').styles(
        border: .all(color: const Color('#7aa2f7'), width: 1.px),
        color: const Color('#ffffff'),
        backgroundColor: const Color('#353535'),
      ),
      css('&:disabled').styles(
        opacity: 0.45,
        cursor: .defaultCursor,
      ),
    ]),
  ];
}
