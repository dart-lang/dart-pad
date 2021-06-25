import 'dart:html';

/// Enables retrieving and setting browser query parameters.
final queryParams = _QueryParams();

/// A singleton for accessing and setting query parameters.
class _QueryParams {
  static _QueryParams _instance;

  const _QueryParams._();

  factory _QueryParams() {
    return _instance ??= const _QueryParams._();
  }

  /// An immutable map of all current query parameters.
  Map<String, String> get parameters {
    return Uri.parse(window.location.toString()).queryParameters;
  }

  /// Whether or not null safety is enabled through query parameters.
  bool get nullSafety {
    final nullSafety = _queryParam('null_safety');

    return nullSafety == 'true';
  }

  set nullSafety(bool enabled) {
    var url = Uri.parse(window.location.toString());
    var params = Map<String, String>.from(url.queryParameters);
    if (enabled) {
      params['null_safety'] = 'true';
    } else if (params.containsKey('null_safety')) {
      params.remove('null_safety');
    } else {
      return;
    }
    url = url.replace(queryParameters: params);
    window.history.replaceState({}, 'DartPad', url.toString());
  }

  /// Whether the `null_safety` query parameter is defined or not.
  bool get hasNullSafety {
    final nullSafety = _queryParam('null_safety');

    return nullSafety != null;
  }

  set gistId(String gistId) {
    var url = Uri.parse(window.location.toString());
    var params = Map<String, String>.from(url.queryParameters);
    params['id'] = gistId;
    url = url.replace(queryParameters: params);
    window.history.replaceState({}, 'DartPad', url.toString());
  }

  String /*?*/ get gistId {
    return _queryParam('id');
  }

  int /*?*/ get line {
    final line = _queryParam('line');

    if (line == null) {
      return null;
    }

    return int.tryParse(line);
  }

  String /*?*/ get theme {
    return _queryParam('theme');
  }

  bool get autoRunEnabled {
    return _queryParam('run') == 'true';
  }

  bool get shouldOpenConsole {
    return _queryParam('open_console') == 'true';
  }

  bool get showInstallButton {
    return _queryParam('install_button') == 'true';
  }

  bool get hasShowInstallButton {
    return _queryParam('install_button') != null;
  }

  String /*?*/ get sampleId {
    return _queryParam('sample_id');
  }

  String /*?*/ get sampleChannel {
    return _queryParam('sample_channel');
  }

  String /*?*/ get githubOwner {
    return _queryParam('gh_owner');
  }

  String /*?*/ get githubRepo {
    return _queryParam('gh_repo');
  }

  String /*?*/ get githubPath {
    return _queryParam('gh_path');
  }

  String /*?*/ get githubRef {
    return _queryParam('gh_ref');
  }

  String /*?*/ get webServer {
    return _queryParam('webserver');
  }

  int /*?*/ get initialSplit {
    final split = _queryParam('split');

    if (split == null) {
      return null;
    }

    return int.tryParse(split);
  }

  String /*?*/ _queryParam(String key) {
    return Uri.parse(window.location.toString()).queryParameters[key];
  }
}
