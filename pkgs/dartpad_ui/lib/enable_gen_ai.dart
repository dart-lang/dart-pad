// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Turn on or off gen-ai features in the client.
const bool genAiEnabled = true;

/*
Command to run locally with gemini replaced with genui:

flutter run -d chrome --web-port 8888 --web-browser-flag "--disable-web-security" \
  --web-launch-url=http://localhost:8888/?channel=localhost&genui=true
*/
