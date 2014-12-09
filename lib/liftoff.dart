
library liftoff;

import 'compiler.dart';
import 'dependencies.dart';
import 'event_bus.dart';

CompilerService getCompilerService() => Dependencies.instance[CompilerService];

EventBus get eventBus => Dependencies.instance[EventBus];
