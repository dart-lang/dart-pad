import 'dart:html';

main() {
  var queryParams = Uri.parse(window.location.toString()).queryParameters;
  var newUrl = Uri.parse('/experimental/embed-new-dart.html');
  if (queryParams.containsKey('fw') && queryParams['fw'] == 'true') {
    newUrl = Uri.parse('/experimental/embed-new-flutter.html');
  }
  newUrl = newUrl.replace(queryParameters: queryParams);
  window.location.assign(newUrl.toString());
}
