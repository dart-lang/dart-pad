// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../elements/bind.dart';
import 'mutable_gist.dart';

class GistFileProperty implements Property<String> {
  final MutableGistFile file;

  GistFileProperty(this.file);

  @override
  String get() => file.content;

  @override
  void set(value) {
    if (file.content != value) {
      file.content = value;
    }
  }

  @override
  Stream<String> get onChanged => file.onChanged.map((value) => value);
}
