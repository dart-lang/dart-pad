// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';

import '../../shared/components/icon_button.dart';
import '../view_models/preview_view_model.dart';

/// A button component used to trigger preview runtime actions
/// (Start, Restart, Hot Reload, Stop).
class RuntimeButton extends StatelessComponent {
  /// Creates a runtime button with direct configurations.
  const RuntimeButton({
    required this.title,
    required this.icon,
    required this.isEnabled,
    required this.onClick,
    super.key,
  });

  /// Factory constructor for a 'Start' button that runs the [activeFile]
  /// or falls back to 'lib/main.dart' if no active file is present.
  factory RuntimeButton.start({
    required PreviewViewModel previewViewModel,
    required String activeFile,
  }) {
    return RuntimeButton(
      title: 'Start',
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

  /// Factory constructor for a 'Hot Reload' button that hot reloads changes
  /// in the currently running entrypoint.
  factory RuntimeButton.hotReload({required PreviewViewModel previewViewModel}) {
    return RuntimeButton(
      title: 'Hot Reload',
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
    return IconButton(
      label: title,
      icon: icon,
      disabled: !isEnabled,
      tooltip: title,
      onClick: (_) => onClick(),
    );
  }
}
