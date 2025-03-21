// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Turn on or off gen-ai features in the client.
const bool genAiEnabled = true;

/*

There are two options to use gen AI: Gemini and GenUI. Gemini is the default.
These are options to exercise GenUI :

1. To use GenUI locally, with local backend:

  a. Set genAiEnabled to true above.

  b. See go/dartpad-manual-genui, section "GenUi Integration"
     for instructions on how to start backend with genui keys configured.

  c. Use this command to run UI:

    flutter run -d chrome --web-port 8888 --web-browser-flag "--disable-web-security" \
      --web-launch-url="http://localhost:8888/?channel=localhost&genui=true"

2. To use GenUI with local UI, but prod backend:

  a. Set genAiEnabled to true above.

  b. Use this command to run UI:

    flutter run -d chrome --web-port 8888 --web-browser-flag "--disable-web-security" \
      --web-launch-url="http://localhost:8888/?genui=true"


3. To use GenUI on  http://preview.dartpad.dev just add `&genui=true` to the URL.

*/
