import 'step.dart';

enum CodelabType { dart, flutter }

class Codelab {
  final String name;
  final CodelabType type;
  final List<Step> steps;
  Codelab(this.name, this.type, this.steps);
}
