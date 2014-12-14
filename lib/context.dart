
library context;

import 'analysis.dart';

abstract class Context {
  List<AnalysisIssue> issues = [];

  String name;
  String description;

  String dartSource;
  String htmlSource;
  String cssSource;
}

abstract class ContextProvider {
  Context get context;
}

class BaseContextProvider extends ContextProvider {
  final Context context;
  BaseContextProvider(this.context);
}
