// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../preview/models/run_mode.dart';
import 'project_loader.dart';
import 'project_source.dart';

/// The immutable, source-relative options supplied by the URL.
///
/// Parsing validates query syntax and path safety. Source loading and project
/// resolution subsequently check file existence, SDK availability, and inferred
/// defaults. Explicit file paths are relative to the source, not to [root].
final class ProjectRequest {
  ProjectRequest._({
    required this.source,
    required Map<String, List<String>> query,
    required List<String> files,
    this.root,
    this.entrypoint,
    this.sdk,
    this.sdkVersion,
    this.mode,
  }) : query = Map.unmodifiable(query.map((key, value) => MapEntry(key, List<String>.unmodifiable(value)))),
       files = List.unmodifiable(files);

  /// Creates a request with only the sample selection set.
  ///
  /// A null [sampleId] selects the default sample (`counter`). An empty ID throws
  /// a [FormatException]; whether the sample exists is checked when loading it.
  factory ProjectRequest.example([String? sampleId]) => ProjectRequest.fromUri(
    Uri(queryParameters: sampleId == null ? null : {'sample': sampleId}),
  );

  /// Parses source selection and initial project options from [uri]'s query.
  ///
  /// Reads [Uri.queryParametersAll] without decoding values a second time,
  /// preserving repeated `file` values in order. With no explicit source, the
  /// request selects the default sample. `gist` and its `id` alias are mutually
  /// exclusive; `version` requires `package`.
  ///
  /// Throws a [FormatException] for conflicting sources, invalid option values,
  /// repeated scalar options, or the unsupported `archive`, `path`, and `main`
  /// parameters. Unsafe or empty file paths throw an [ArgumentError]. An empty
  /// `root` is valid and explicitly selects the source root.
  ///
  /// Other query parameters, including the independent `embed` UI option, are
  /// retained in [query] without being interpreted here.
  factory ProjectRequest.fromUri(Uri uri) {
    final query = uri.queryParametersAll;
    String? single(String key) {
      final values = query[key];
      if (values == null) {
        return null;
      }
      if (values.length != 1 || (values.single.isEmpty && key != 'root')) {
        throw FormatException('Expected one non-empty "$key" parameter.');
      }
      return values.single;
    }

    for (final obsolete in ['archive', 'path', 'main']) {
      if (query.containsKey(obsolete)) {
        throw FormatException('Unsupported query parameter: $obsolete.');
      }
    }
    final url = single('url');
    final package = single('package');
    final version = single('version');
    final gist = single('gist');
    final id = single('id');
    final sample = single('sample');
    if (gist != null && id != null) {
      throw const FormatException('Choose either gist or id, not both.');
    }
    if ([url, package, gist ?? id, sample].nonNulls.length > 1) {
      throw const FormatException('Choose only one project source.');
    }
    if (version != null && package == null) {
      throw const FormatException('version requires package.');
    }
    final sdkValue = single('sdk');
    final sdkParts = sdkValue?.split(':');
    if (sdkParts != null &&
        (sdkParts.length > 2 || !['dart', 'flutter'].contains(sdkParts.first) || sdkParts.last.isEmpty)) {
      throw const FormatException('sdk must be dart or flutter, optionally followed by :<version>.');
    }
    final modeValue = single('mode');
    if (modeValue != null && !RunMode.values.any((mode) => mode.name == modeValue)) {
      throw const FormatException('mode must be console or flutter.');
    }
    final root = single('root');
    final entrypoint = single('entrypoint');
    final files = query['file'] ?? const <String>[];
    for (final path in [...files, ?entrypoint]) {
      ProjectLoader.normalizePath(path);
    }
    if (root != null) {
      ProjectLoader.normalizePath(root, allowRoot: true);
    }
    return ProjectRequest._(
      source: url != null
          ? ArchiveProjectSource(url)
          : package != null
          ? PackageProjectSource(package, version: version)
          : (gist ?? id) != null
          ? GistProjectSource((gist ?? id)!)
          : SampleProjectSource(sample),
      query: query,
      files: files,
      root: root,
      entrypoint: entrypoint,
      sdk: sdkParts?.first,
      sdkVersion: sdkParts != null && sdkParts.length == 2 ? sdkParts.last : null,
      mode: modeValue == null ? null : RunMode.values.byName(modeValue),
    );
  }

  /// The selected source, defaulting to a sample when none was specified.
  final ProjectSource source;

  /// The original decoded query values, including options not interpreted here.
  ///
  /// The map and each value list are unmodifiable. Repeated values retain their
  /// order within each parameter.
  final Map<String, List<String>> query;

  /// Explicit source-relative tab paths in query order, including duplicates.
  ///
  /// This list is unmodifiable. Empty selects README.md in the resolved root,
  /// then the resolved entrypoint, or no initial tab if neither exists.
  final List<String> files;

  /// Null infers the project root. Empty explicitly selects the source root;
  /// a non-empty value names a source-relative directory.
  final String? root;

  /// The explicit source-relative execution target, or null to infer one.
  ///
  /// File existence is checked during project resolution. Empty values are
  /// invalid, rather than an instruction to disable Run.
  final String? entrypoint;

  /// The requested SDK kind (`dart` or `flutter`).
  ///
  /// Null infers the kind from the resolved root's pubspec.
  final String? sdk;

  /// The exact SDK version requested after the colon in the `sdk` parameter.
  ///
  /// Null selects the first available bundle of the chosen SDK kind. Bundle
  /// availability is checked during project resolution.
  final String? sdkVersion;

  /// Null infers mode from the SDK and entrypoint; a value fixes the mode.
  final RunMode? mode;

  /// Re-encodes [query] for the browser URL, including repeated parameters.
  ///
  /// Returns a query string prefixed with `?`, or an empty string for no query.
  String get search {
    final encoded = Uri(queryParameters: query).query;
    return encoded.isEmpty ? '' : '?$encoded';
  }
}
