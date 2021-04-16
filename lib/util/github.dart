import 'dart:convert';

/// Returns the contents of the file returned from
/// api.github.com/repos/<owner>/<repo>/contents/<file_path>
String extractGitHubResponseBody(String githubResponse) {
  // GitHub's API returns file contents as the "contents" field in a JSON
  // object. The field's value is in base64 encoding, but with line ending
  // characters ('\n') included.
  final contentJson = json.decode(githubResponse);
  final encodedContentStr =
      contentJson['content'].toString().replaceAll('\n', '');
  return utf8.decode(base64.decode(encodedContentStr));
}
