// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:logging/logging.dart';

import '../../bottom_panel/view_models/console_view_model.dart';
import '../../bottom_panel/view_models/diagnostics_view_model.dart';
import '../../editor/codemirror/code_mirror_tab.dart';
import '../../editor/view_models/tabs_view_model.dart';
import '../../filetree/file_tree_view_model.dart';
import '../../preview/view_models/preview_view_model.dart';
import '../../workspace/data/workspace_repository.dart';
import '../../workspace/workspace_session.dart';
import '../app_event_bus.dart';
import '../events/log_event.dart';
import '../task_status.dart';
import 'shortcut_definitions.dart';

/// Execution context provided to commands executed from the command palette.
///
/// Encapsulates the active [session], the current [projectDir], and convenient
/// accessors to common services.
final class CommandContext {
  const CommandContext({
    this.session,
    this.projectDir = '',
  });

  /// The active [WorkspaceSession], or `null` in headless/test environments where
  /// actions do not interact with a workspace.
  final WorkspaceSession? session;

  /// The relative directory of the active project within the workspace.
  final String projectDir;

  WorkspaceRepository? get repository => session?.repository;

  TabsViewModel? get tabs => session?.tabs;

  AppEventBus? get events => session?.events;

  PreviewViewModel? get preview => session?.preview;

  ConsoleViewModel? get console => session?.console;

  DiagnosticsViewModel? get diagnostics => session?.diagnostics;

  FileTreeViewModel? get fileTree => session?.fileTree;

  TaskStatusController? get taskStatus => session?.taskStatus;
}

/// An executable command shown in the command palette.
///
/// Encapsulates command metadata and execution logic. If a command can be triggered
/// by an existing keyboard shortcut, [shortcut] or [CommandPaletteAction.fromShortcut] links to that
/// [ShortcutDefinition], ensuring display keys and labels are defined only once.
final class CommandPaletteAction {
  const CommandPaletteAction({
    required this.label,
    this.description = '',
    this.aliases = const [],
    this.shortcut,
    this.category,
    required this.onExecute,
    this.isEnabled,
  });

  /// Creates a [CommandPaletteAction] from an existing [ShortcutDefinition].
  ///
  /// The [shortcut] provides the default [label], [category], and display key.
  factory CommandPaletteAction.fromShortcut({
    required ShortcutDefinition shortcut,
    String description = '',
    List<String> aliases = const [],
    required FutureOr<void> Function(CommandContext context) onExecute,
    bool Function(CommandContext context)? isEnabled,
  }) => CommandPaletteAction(
    label: shortcut.label,
    description: description,
    aliases: aliases,
    shortcut: shortcut,
    category: shortcut.category,
    onExecute: onExecute,
    isEnabled: isEnabled,
  );

  /// The human-readable name of the command shown in the palette.
  final String label;

  /// One sentence human description of the command.
  final String description;

  /// Aliases for consideration in auto-complete and search matching.
  final List<String> aliases;

  /// Optional keyboard shortcut associated with this command.
  final ShortcutDefinition? shortcut;

  /// Optional category used for grouping and search matching.
  final ShortcutCategory? category;

  /// Callback executed when this command is selected.
  final FutureOr<void> Function(CommandContext context) onExecute;

  /// Optional predicate that determines whether this command can be executed.
  final bool Function(CommandContext context)? isEnabled;

  /// The platform-resolved display key (e.g. `⌘ + Enter` on macOS, `Ctrl + Enter` on Windows),
  /// or an empty string if this command has no shortcut.
  String get resolvedDisplayKey => shortcut?.resolvedDisplayKey ?? '';
}

const pubGetAction = CommandPaletteAction(
  label: 'Pub get',
  description: 'Download and resolve package dependencies',
  aliases: ['get', 'packages get', 'install'],
  onExecute: _executePubGet,
);

const pubUpgradeAction = CommandPaletteAction(
  label: 'Pub upgrade',
  description: 'Upgrade package dependencies to their latest allowed versions',
  aliases: ['upgrade', 'update', 'packages upgrade'],
  onExecute: _executePubUpgrade,
);

const pubOutdatedAction = CommandPaletteAction(
  label: 'Pub outdated',
  description: 'Analyze dependencies to find which packages have newer versions',
  aliases: ['outdated', 'check updates'],
  onExecute: _executePubOutdated,
);

const pubDowngradeAction = CommandPaletteAction(
  label: 'Pub downgrade',
  description: 'Downgrade package dependencies to their lowest allowed versions',
  aliases: ['downgrade'],
  onExecute: _executePubDowngrade,
);

const pubCleanAction = CommandPaletteAction(
  label: 'Pub clean',
  description: 'Remove build and cache artifacts from the workspace',
  aliases: ['clean'],
  onExecute: _executePubClean,
);

const formatDocumentAction = CommandPaletteAction(
  label: 'Format document',
  description: 'Format the currently active document',
  aliases: ['format', 'beautify', 'indent'],
  shortcut: ShortcutDefinition.formatDocument,
  category: ShortcutCategory.refactoring,
  onExecute: _executeFormatDocument,
);

const runOrHotReloadAction = CommandPaletteAction(
  label: 'Run / Hot reload',
  description: 'Run the application or trigger a hot reload if already running',
  aliases: ['run', 'reload', 'hot reload', 'restart'],
  shortcut: ShortcutDefinition.runOrHotReload,
  category: ShortcutCategory.execution,
  onExecute: _executeRunOrHotReload,
);

const saveFileAction = CommandPaletteAction(
  label: 'Save file',
  description: 'Save changes in the currently open editor tab',
  aliases: ['save', 'save file', 'write'],
  shortcut: ShortcutDefinition.save,
  onExecute: _executeSaveFile,
);

/// The complete default list of registered [CommandPaletteAction]s.
const allCommandActions = <CommandPaletteAction>[
  pubGetAction,
  pubUpgradeAction,
  pubOutdatedAction,
  pubDowngradeAction,
  pubCleanAction,
  formatDocumentAction,
  runOrHotReloadAction,
  saveFileAction,
];

Future<void> _executePubGet(CommandContext context) async {
  final session = context.session;
  if (session == null) {
    return;
  }
  try {
    await session.tabs.saveAllTabs();
  } catch (_) {
    return;
  }
  try {
    await session.repository.pubGet(
      path: context.projectDir,
      projectRoot: context.projectDir,
    );
  } catch (error, stackTrace) {
    session.events.dispatch(
      LogEvent(
        'Pub get failed.',
        level: Level.SEVERE,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

Future<void> _executePubUpgrade(CommandContext context) async {
  final session = context.session;
  if (session == null) {
    return;
  }
  try {
    await session.tabs.saveAllTabs();
  } catch (_) {
    return;
  }
  try {
    await session.repository.pubUpgrade(
      path: context.projectDir,
      projectRoot: context.projectDir,
    );
  } catch (error, stackTrace) {
    session.events.dispatch(
      LogEvent(
        'Pub upgrade failed.',
        level: Level.SEVERE,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

Future<void> _executePubOutdated(CommandContext context) async {
  final session = context.session;
  if (session == null) {
    return;
  }
  try {
    await session.repository.pubOutdated(
      path: context.projectDir,
      projectRoot: context.projectDir,
    );
  } catch (error, stackTrace) {
    session.events.dispatch(
      LogEvent(
        'Pub outdated failed.',
        level: Level.SEVERE,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

Future<void> _executePubDowngrade(CommandContext context) async {
  final session = context.session;
  if (session == null) {
    return;
  }
  try {
    await session.tabs.saveAllTabs();
  } catch (_) {
    return;
  }
  try {
    await session.repository.pubDowngrade(
      path: context.projectDir,
      projectRoot: context.projectDir,
    );
  } catch (error, stackTrace) {
    session.events.dispatch(
      LogEvent(
        'Pub downgrade failed.',
        level: Level.SEVERE,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

Future<void> _executePubClean(CommandContext context) async {
  final session = context.session;
  if (session == null) {
    return;
  }
  try {
    await session.repository.pubClean(
      path: context.projectDir,
    );
  } catch (error, stackTrace) {
    session.events.dispatch(
      LogEvent(
        'Pub clean failed.',
        level: Level.SEVERE,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

Future<void> _executeFormatDocument(CommandContext context) async {
  final session = context.session;
  if (session == null) {
    return;
  }
  final tab = session.tabs.activeTab;
  if (tab is WorkspaceCodeMirrorTab) {
    await tab.editor.format();
  }
}

Future<void> _executeRunOrHotReload(CommandContext context) async {
  context.session?.runOrHotReload();
}

Future<void> _executeSaveFile(CommandContext context) async {
  final session = context.session;
  if (session == null) {
    return;
  }
  final activeFile = session.tabs.activeFile;
  if (activeFile.isNotEmpty) {
    await session.tabs.saveTab(activeFile);
  } else {
    await session.tabs.saveAllTabs();
  }
}
