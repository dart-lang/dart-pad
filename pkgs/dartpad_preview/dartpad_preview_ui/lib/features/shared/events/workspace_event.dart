part of '../app_event_bus.dart';

/// Fired when the [WorkspaceRepository] has been initialized.
class WorkspaceInitializedEvent extends AppEvent {
  const WorkspaceInitializedEvent(this.workspace);

  final WorkspaceRepository workspace;
}
