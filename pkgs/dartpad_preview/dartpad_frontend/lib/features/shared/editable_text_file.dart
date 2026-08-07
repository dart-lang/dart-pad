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

/// Browser MIME types for image extensions rendered in an editor preview tab.
const Map<String, String> _imageMimeTypesByExtension = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
};

/// Image extensions that can be rendered in an editor preview tab.
final Set<String> supportedImageExtensions = Set.unmodifiable(
  _imageMimeTypesByExtension.keys,
);

/// Returns the browser MIME type for a supported image file, if any.
String? imageMimeTypeForPath(String path) {
  final lower = path.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot == -1 || dot == lower.length - 1) {
    return null;
  }
  return _imageMimeTypesByExtension[lower.substring(dot)];
}

/// Whether [path] can be displayed as an image preview in the editor.
bool isPreviewableImageFile(String path) => imageMimeTypeForPath(path) != null;

/// Whether [path] can be represented as editable text.
bool isEditableTextFile(String path) {
  final lower = path.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot == -1 || dot == lower.length - 1) {
    return true;
  }
  return !_binaryExtensions.contains(lower.substring(dot));
}

/// Whether [path] can be opened in either an editor or a preview tab.
bool isEditorOpenableFile(String path) => isEditableTextFile(path) || isPreviewableImageFile(path);
