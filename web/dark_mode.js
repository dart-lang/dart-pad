/**
 * Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
 * for details. All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

(function() {
    var params = new URLSearchParams(window.location.search);
    if (params.get('theme') == 'dark') {
        document.write(
            '<link rel="stylesheet" type="text/css" href="styles/embed/styles_dark.css">'
        );
    } else {
        document.write(
            '<link rel="stylesheet" type="text/css" href="styles/embed/styles_light.css">'
        )
    }
})();
