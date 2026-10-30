// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../preview/models/run_mode.dart';
import '../shared/panel_hints.dart';
import '../shared/sdk_kind.dart';
import 'examples.g.dart';
import 'project_source.dart';
import 'query_parameters.dart';

/// The immutable, source-relative options supplied by the URL.
///
/// Holds the validated query and the raw [query] used to rebuild the browser
/// URL. Source loading and project resolution subsequently check file existence,
/// SDK availability, and inferred defaults. Explicit file paths are relative to the
/// source, not to [root].
final class ProjectRequest {
  ProjectRequest._({
    required this.source,
    required this._parameters,
    this.sampleInitialFile,
  });

  /// Creates a request with only the sample selection set.
  ///
  /// A null [sampleId] selects the default sample (`counter`). An empty ID throws
  /// a [FormatException]; whether the sample exists is checked when loading it.
  factory ProjectRequest.example([String? sampleId]) => ProjectRequest.fromUri(
    Uri(queryParameters: sampleId == null ? null : {QueryParameters.sample: sampleId}),
  );

  /// Parses source selection and initial project options from [uri]'s query.
  ///
  /// Validation lives in [QueryParameters.fromUri]. This reads [Uri.queryParametersAll]
  /// without decoding values a second time, preserving repeated `file` values in order.
  ///
  /// Throws a [FormatException] for conflicting sources, invalid option values,
  /// repeated scalar options, or the unsupported `archive`, `path`, and `main`
  /// parameters. Unsafe or empty file paths throw an [ArgumentError]. An empty
  /// `root` is valid and explicitly selects the source root.
  ///
  /// Other query parameters, including the independent `embed` UI option, are
  /// retained in [query].
  factory ProjectRequest.fromUri(Uri uri) {
    final parameters = QueryParameters.fromUri(uri);
    final example = switch (parameters.source) {
      UrlSourceSelection() || PackageSourceSelection() || GistSourceSelection() => null,
      SampleSourceSelection(:final sampleId) => Examples.getById(sampleId),
      _ => Examples.defaultExample,
    };
    return ProjectRequest._(
      source: switch (parameters.source) {
        UrlSourceSelection(:final url) => ArchiveProjectSource(url),
        PackageSourceSelection(:final package, :final version) => PackageProjectSource(package, version: version),
        GistSourceSelection(:final gistId) => GistProjectSource(gistId),
        ApiDocsSourceSelection(:final sampleId, :final channel) => FlutterApiDocsProjectSource(
          sampleId,
          channel: channel,
        ),
        SampleSourceSelection(:final sampleId) => SampleProjectSource(sampleId),
        null => const SampleProjectSource(),
      },
      parameters: parameters,
      sampleInitialFile: example?.initialFile,
    );
  }

  /// The selected source, defaulting to a sample when none was specified.
  final ProjectSource source;

  /// The validated query. Source, project, and appearance values are read from here.
  final QueryParameters _parameters;

  /// The selected sample's preferred first tab, separate from URL `file` options.
  ///
  /// It does not change [query], so history matches the URL that was opened.
  final String? sampleInitialFile;

  /// The decoded query values, including options not interpreted here.
  /// Panel hints retain their signs and have surrounding whitespace removed.
  ///
  /// Kept so [search] and history match the URL that was opened. The map and each
  /// value list are unmodifiable. Repeated values retain their order within each
  /// parameter.
  Map<String, List<String>> get query => _parameters.raw;

  /// The per-tab session id from the `s` parameter, or null when absent or invalid.
  SessionId? get session => _parameters.session;

  /// Explicit source-relative tab paths in query order, including duplicates.
  ///
  /// This list is unmodifiable. When empty and no root or entrypoint is
  /// specified, a sample's [sampleInitialFile] takes priority. Resolution then
  /// tries README.md in the resolved root and the resolved entrypoint.
  List<String> get files => _parameters.project.files;

  /// Null infers the project root. Empty explicitly selects the source root;
  /// a non-empty value names a source-relative directory.
  String? get root => _parameters.project.root;

  /// The explicit source-relative execution target, or null to infer one.
  ///
  /// File existence is checked during project resolution. Empty values are
  /// invalid, rather than an instruction to disable Run.
  String? get entrypoint => _parameters.project.entrypoint;

  /// The requested SDK kind (`dart` or `flutter`).
  ///
  /// Null infers the kind from the resolved root's pubspec.
  SdkKind? get sdk => _parameters.project.sdk;

  /// The exact SDK version requested after the colon in the `sdk` parameter.
  ///
  /// Null selects the first available bundle of the chosen SDK kind. Bundle
  /// availability is checked during project resolution.
  String? get sdkVersion => _parameters.project.sdkVersion;

  /// Null infers mode from the SDK and entrypoint; a value fixes the mode.
  RunMode? get mode => _parameters.project.mode;

  /// Whether the current preview embed presentation should be used.
  bool get isEmbedded => _parameters.appearance.embed;

  /// Whether the URL names a source, rather than a bare URL using the default sample.
  bool get isSourced => _parameters.source != null;

  /// Whether the resolved entrypoint should run after workspace preparation.
  /// Embeds wait for Run except legacy Flutter API docs samples ending in `.1`.
  /// The obsolete `run` query parameter is ignored.
  bool get autoRun =>
      !isEmbedded ||
      switch (source) {
        FlutterApiDocsProjectSource(:final sampleId) => sampleId.endsWith('.1'),
        _ => false,
      };

  /// Initial fraction of the outer split occupied by the preview panel, or null to use the layout default.
  /// The requested value is clamped to 5–95% by [QueryParameters].
  /// This is only to support the old docs generator and will be removed in the future.
  double? get initialSplitRatio {
    final percent = _parameters.appearance.splitPercent;
    return percent == null ? null : percent / 100;
  }

  /// Initial layout hints, resolved against the standalone or embed defaults.
  PanelHints get panels => _parameters.appearance.panels;

  /// Re-encodes [query] for the browser URL, including repeated parameters.
  ///
  /// Returns a query string prefixed with `?`, or an empty string for no query.
  String get search {
    final encoded = Uri(queryParameters: query).query;
    return encoded.isEmpty ? '' : '?$encoded';
  }
}
