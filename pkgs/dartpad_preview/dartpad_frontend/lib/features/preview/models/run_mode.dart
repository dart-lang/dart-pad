// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';

import '../../shared/sdk_info.dart';

/// Execution modes exposed by the DartPad sandbox.
enum RunMode {
  /// Pure Dart console application execution.
  console('console'),

  /// Flutter web application execution.
  flutter('flutter');

  const RunMode(this.mode);

  /// The string identifier used by the preview sandbox protocol.
  final String mode;

  /// Resolves a mode from current workspace files before creating a preview.
  ///
  /// An explicit [modeOverride] takes precedence. Otherwise, a missing
  /// [entrypoint] or a Dart SDK selects console mode; Flutter mode is inferred
  /// relative to the entrypoint's nearest pubspec. Rejects a Flutter override
  /// when [sdk] is a Dart SDK.
  static Future<RunMode> resolve({
    required WorkspaceResourceApi workspace,
    required SdkInfo sdk,
    required String? entrypoint,
    RunMode? modeOverride,
  }) async {
    if (modeOverride != null) {
      if (modeOverride == flutter && !sdk.isFlutter) {
        throw const FormatException('Flutter mode requires a Flutter SDK.');
      }
      return modeOverride;
    }
    if (entrypoint == null || !sdk.isFlutter) {
      return console;
    }
    var folder = parentWorkspacePath(entrypoint);
    while (folder.isNotEmpty && !await workspace.fileExist(joinWorkspacePath(folder, 'pubspec.yaml'))) {
      folder = parentWorkspacePath(folder);
    }
    return forEntrypoint(sdk: sdk, entrypoint: entrypoint, packageRoot: folder);
  }

  /// Infers execution mode relative to the entrypoint's nearest package root.
  /// The empty [packageRoot] represents the source root.
  static RunMode forEntrypoint({required SdkInfo sdk, required String entrypoint, required String packageRoot}) {
    final relative = workspacePath.relative(entrypoint, from: packageRoot.isEmpty ? '.' : packageRoot);
    return sdk.isFlutter && !['bin', 'test', 'tool'].contains(relative.split('/').first) ? flutter : console;
  }
}
