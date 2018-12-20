// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.media_message;

/// Special API Message to use when a method returns a Blob.
class MediaMessage {
  /// Blob data as bytes.
  List<int> bytes;

  /// The creation or modification time of the media. Optional.
  DateTime updated;

  /// Content-Type of the object data. Optional.
  String contentType;

  /// Cache-Control directive for the media data. Optional.
  String cacheControl;

  /// Content-Encoding of the media data. Optional.
  String contentEncoding;

  /// Content-Type of the media data. Optional.
  String contentLanguage;

  /// MD5 hash of the data; encoded using base64. Optional.
  String md5Hash;

  /// User-provided metadata, in key/value pairs. Optional.
  Map<String, String> metadata;
}
