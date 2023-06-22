import 'step.dart';

enum WorkshopType { dart, flutter }

class Workshop {
  final String name;
  final WorkshopType type;
  final List<Step> steps;
  Workshop(this.name, this.type, this.steps);
}
