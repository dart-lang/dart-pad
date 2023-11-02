import 'package:go_router/go_router.dart';

extension GoRouteHelpers on GoRouter {
  void replaceQueryParam(String param, String? value) {
    var queryParameters = routeInformationProvider.value.uri.queryParameters;
    var newQueryParameters = Map<String, String>.from(queryParameters);
    if (value == null) {
      newQueryParameters.remove(param);
    } else {
      newQueryParameters[param] = value;
    }

    go(routeInformationProvider.value.uri
        .replace(queryParameters: newQueryParameters)
        .toString());
  }
}
