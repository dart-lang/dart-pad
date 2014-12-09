
library liftoff.all_test;

import 'dependencies_test.dart' as dependencies_test;
import 'event_bus_test.dart' as event_bus_test;

void main() => defineTests();

void defineTests() {
  dependencies_test.defineTests();
  event_bus_test.defineTests();
}
