// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.sample;

final String dartCode = r'''
// Welcome to the null safety version of DartPad!
// This site has a dev channel release of the
// Dart SDK with null safety enabled. You can
// play around with code of your own, or pick a
// learning exercise from the snippets menu at
// the top-right of this page.

void main() {
  for (int i = 0; i < 5; i++) {
    print('hello ${i + 1}');
  }
}
''';

final String dartCodeHtml = r'''
import 'dart:html';

void main() {
  var header = querySelector('#header');
  header.text = "Hello, World!";
}
''';

final String htmlCode = r'''
<h1 id="header"></h1>
''';

final String cssCode = r'''
body {
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  position: absolute;
  width: 100%;
  height: 100%;
}

h1 {
  color: white;
  font-family: Arial, Helvetica, sans-serif;
}
''';

final String flutterCode = r'''
import 'package:flutter/material.dart';

final Color darkBlue = Color.fromARGB(255, 18, 32, 47);

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: darkBlue),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: MyWidget(),
        ),
      ),
    );
  }
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('Hello, World!', style: Theme.of(context).textTheme.headline4);
  }
}
''';
