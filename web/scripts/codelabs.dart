import 'package:dart_pad/codelab.dart';
import 'package:logging/logging.dart';

void main() {
  init();

  Logger.root.onRecord.listen(print);
}
