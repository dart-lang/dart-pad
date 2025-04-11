// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Turn on or off gen-ai features in the client.
const bool genAiEnabled = true;

// Set to true to use GenUI instead of Gemini.
// This is a temporary flag to test GenUI in production.
// It will be removed once GenUI is fully integrated.
// The flag is set based on URL parameter in main.dart.
bool useGenUI = false;

/*

There are two options to use gen AI: Gemini and GenUI. Gemini is the default.
To run with GenUI, use corresponding VS Code configuration or the command line options:

1. With prod backend: add URL parameter `/?genui=true`

2. With local backend:

    a. See go/dartpad-manual-genui for instructions on how to start backend with
    GENUI_API_KEY.

    b. Use this command to run the UI:

        flutter run -d chrome --web-port 8888 --web-browser-flag "--disable-web-security" \
          --web-launch-url="http://localhost:8888/?channel=localhost&genui=true"

*/
