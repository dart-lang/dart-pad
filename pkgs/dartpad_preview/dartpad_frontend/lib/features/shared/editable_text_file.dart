// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

const Set<String> _binaryExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.bmp',
  '.ico',
  '.webp',
  '.avif',
  '.ttf',
  '.otf',
  '.woff',
  '.woff2',
  '.eot',
  '.dill',
  '.exe',
  '.dll',
  '.so',
  '.dylib',
  '.class',
  '.o',
  '.obj',
  '.wasm',
  '.zip',
  '.tar',
  '.gz',
  '.bz2',
  '.7z',
  '.rar',
  '.mp3',
  '.mp4',
  '.ogg',
  '.wav',
  '.avi',
  '.mov',
  '.flv',
  '.webm',
  '.pdf',
  '.db',
  '.sqlite',
};

/// Whether [path] can be represented as editable text.
bool isEditableTextFile(String path) {
  final lower = path.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot == -1 || dot == lower.length - 1) {
    return true;
  }
  return !_binaryExtensions.contains(lower.substring(dot));
}
