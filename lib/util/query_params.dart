import 'dart:html';

class QueryParams {
  static bool get nullSafety {
    var url = Uri.parse(window.location.toString());

    if (url.hasQuery &&
        url.queryParameters['null_safety'] != null &&
        url.queryParameters['null_safety'] == 'true') {
      return true;
    }

    return false;
  }

  static bool get hasNullSafety {
    var url = Uri.parse(window.location.toString());
    return url.hasQuery && url.queryParameters['null_safety'] != null;
  }
}
