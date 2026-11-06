// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

(function () {
  const queryTheme = new URLSearchParams(window.location.search).get('theme');
  const userTheme =
    queryTheme === 'dark' || queryTheme === 'light'
      ? queryTheme
      : window.localStorage.getItem('dartpad:theme');
  document.documentElement.setAttribute('data-theme', userTheme ?? 'dark');
})();
