import "click_handler_test.dart" as click_handler_test;
import "client_test.dart" as client_test;
import "link_matcher_test.dart" as link_matcher_test;
import "url_template_test.dart" as url_template_test;

/// Run tests from project root directory with the following command:
/// pub run test -p "content-shell,dartium,chrome,safari" test/all_web_tests.dart
main() {
  click_handler_test.main();
  client_test.main();
  link_matcher_test.main();
  url_template_test.main();
}
