import 'package:go_router/go_router.dart';

extension GoRouteHelpers on GoRouter {
  /// Calls go() with the existing query parameters and replaces
  /// [param] with [value]. If [value] is null, the parameter
  /// is removed.
  void replaceQueryParam(String param, String? value) {
    final queryParameters = routeInformationProvider.value.uri.queryParameters;
    final newQueryParameters = Map<String, String>.from(queryParameters);

    if (value == null) {
      newQueryParameters.remove(param);
    } else {
      newQueryParameters[param] = value;
    }

    final newUri = routeInformationProvider.value.uri;
    go(newUri.replace(queryParameters: newQueryParameters).toString());
  }
}
