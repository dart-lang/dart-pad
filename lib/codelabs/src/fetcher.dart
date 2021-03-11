import 'codelab.dart';

abstract class CodelabFetcher {
  Future<Codelab> getCodelab();
}
