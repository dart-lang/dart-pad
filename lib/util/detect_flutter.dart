// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Returns whether [fileContent] appears to use Flutter.
bool hasFlutterContent(String fileContent) {
  return fileContent.contains('package:flutter/') ||
      fileContent.contains('package:flutter_test/') ||
      fileContent.contains('dart:ui') ||
      hasFirebaseContent(fileContent);
}

/// Returns whether [fileContent] appears to use the 'dart:html' library.
bool hasHtmlContent(String fileContent) {
  return fileContent.contains('dart:html');
}

/// Returns whether [fileContent] appears to use Firebase packages.
bool hasFirebaseContent(String fileContent) {
  return fileContent.contains('package:cloud_firestore/') ||
      fileContent.contains('package:firebase_core/') ||
      fileContent.contains('package:firebase/') ||
      fileContent.contains('package:firebase_auth/');
}
