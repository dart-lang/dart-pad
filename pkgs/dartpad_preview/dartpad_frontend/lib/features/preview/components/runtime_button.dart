// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../shared/icons.dart';
import '../view_models/preview_view_model.dart';

/// A button component used to trigger preview runtime actions
/// (Run, Restart, Reload, Stop).
class RuntimeButton extends StatelessComponent {
  /// Creates a runtime button with direct configurations.
  const RuntimeButton({
    required this.title,
    required this.icon,
    required this.isEnabled,
    required this.onClick,
    super.key,
  });

  /// Factory constructor for a 'Run' button that runs the [activeFile]
  /// or falls back to 'lib/main.dart' if no active file is present.
  factory RuntimeButton.run({
    required PreviewViewModel previewViewModel,
    required String activeFile,
  }) {
    return RuntimeButton(
      title: 'Run',
      icon: 'play_arrow',
      isEnabled: previewViewModel.canStart,
      onClick: () => previewViewModel.runCode(
        activeFile.isNotEmpty ? activeFile : 'lib/main.dart',
      ),
    );
  }

  /// Factory constructor for a 'Restart' button that recompiles and restarts
  /// execution of the currently running entrypoint.
  factory RuntimeButton.restart({required PreviewViewModel previewViewModel}) {
    return RuntimeButton(
      title: 'Restart',
      icon: 'restart_alt',
      isEnabled: previewViewModel.canRestart,
      onClick: () => previewViewModel.runCode(
        previewViewModel.state.entrypoint ?? 'lib/main.dart',
      ),
    );
  }

  /// Factory constructor for a 'Reload' button that hot reloads changes
  /// in the currently running entrypoint.
  factory RuntimeButton.reload({required PreviewViewModel previewViewModel}) {
    return RuntimeButton(
      title: 'Reload',
      icon: 'bolt',
      isEnabled: previewViewModel.canHotReload,
      onClick: () => previewViewModel.hotReloadCode(),
    );
  }

  /// Factory constructor for a 'Stop' button that terminates execution
  /// and stops the running application preview.
  factory RuntimeButton.stop({required PreviewViewModel previewViewModel}) {
    return RuntimeButton(
      title: 'Stop',
      icon: 'stop',
      isEnabled: previewViewModel.canStop,
      onClick: () => previewViewModel.stopCode(),
    );
  }

  /// The tooltip/accessible title of the button.
  final String title;

  /// The name of the icon to render within the button.
  final String icon;

  /// Whether the button is enabled for interaction.
  final bool isEnabled;

  /// Callback executed when the button is clicked.
  final Future<void> Function() onClick;

  @override
  Component build(BuildContext context) {
    return button(
      classes: [
        'runtime-button',
        if (!isEnabled) 'disabled',
      ].join(' '),
      disabled: !isEnabled,
      attributes: {
        'title': title,
        'aria-label': title,
      },
      onClick: isEnabled ? () => unawaited(onClick()) : null,
      [
        Icon(icon, size: 18.0),
        span(classes: 'runtime-button-label', [.text(title)]),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.runtime-button', [
      css('&').styles(
        display: .flex,
        position: const .relative(),
        width: 28.px,
        height: 28.px,
        padding: .zero,
        border: .none,
        radius: .circular(4.px),
        cursor: .pointer,
        transition: Transition('background-color', duration: 150.ms, curve: .ease),
        justifyContent: .center,
        alignItems: .center,
        color: colorOnSurface,
        whiteSpace: .noWrap,
        backgroundColor: Colors.transparent,
      ),
      css('& > *').styles(
        raw: {'flex-shrink': '0'},
      ),
      css('&:not(:disabled):hover').styles(
        backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
      ),
      css('&:disabled').styles(
        opacity: 0.5,
        cursor: .notAllowed,
      ),
      css('.runtime-button-label').styles(
        display: .none,
        color: colorOnSurface,
        fontSize: 13.px,
        fontWeight: .w500,
        whiteSpace: .noWrap,
      ),
    ]),
  ];
}
