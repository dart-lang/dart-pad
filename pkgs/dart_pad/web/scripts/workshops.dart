import 'package:dart_pad/workshops.dart';
import 'package:logging/logging.dart';

void main() {
  init();

  Logger.root.onRecord.listen(print);
}
