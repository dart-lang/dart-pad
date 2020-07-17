@JS()
library localstorage;

import 'package:js/js.dart';

@JS('window.localstorage')
external Object get localStorage;