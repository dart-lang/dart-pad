
library liftoff;

import 'analysis.dart';
import 'compiler.dart';
import 'context.dart';
import 'dependencies.dart';
import 'editing/editor.dart';
import 'event_bus.dart';

Context get context => deps[Context];

CompilerService get compilerService => deps[CompilerService];

AnalysisIssueService get analysisService => deps[AnalysisIssueService];

EventBus get eventBus => deps[EventBus];

EditorFactory get editorFactory => deps[EditorFactory];
