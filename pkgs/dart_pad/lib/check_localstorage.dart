@JS()
library check_localstorage;

import 'package:js/js.dart';

// Checks if Local Storage is enabled. Disabling cookies will typically disable
// Local Storage too.
//
// The implementation of this function is defined in
// web/scripts/check_localstorage.js
@JS()
external bool checkLocalStorage();
