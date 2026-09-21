// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../shared/sdk_info.dart';

/// Storage decisions made before loading a project's files.
final class PersistenceLoadStrategy {
  const PersistenceLoadStrategy({this.restoreProjectId, this.offerProjectId});

  /// Read and open this entry instead of loading the URL's source.
  final String? restoreProjectId;

  /// Offer this previous entry after loading and saving the fresh project.
  final String? offerProjectId;
}

/// A matching history entry that can still be restored from the toolbar.
final class ProjectRestoreOffer {
  const ProjectRestoreOffer({required this.projectId, required this.expires, required this.duration});

  final String projectId;
  final DateTime expires;
  final Duration duration;
}

/// Persistence outcomes rendered by the UI; contains no presentation text.
sealed class PersistenceNotice {
  const PersistenceNotice();
}

final class ProjectHistoryUnavailable extends PersistenceNotice {
  const ProjectHistoryUnavailable();
}

final class ProjectSaveFailed extends PersistenceNotice {
  const ProjectSaveFailed();
}

final class RestoredWithDifferentSdk extends PersistenceNotice {
  const RestoredWithDifferentSdk(this.sdk);

  final SdkInfo sdk;
}
