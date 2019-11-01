// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.sample;

final String dartCode = r'''
void main() {
  for (int i = 0; i < 5; i++) {
    print('hello ${i + 1}');
  }
}
''';

final String dartCodeHtml = r'''
import 'dart:html';

void main() {
  var logo = querySelector('#logo');
  logo.onClick.listen((_) {
    if (logo.classes.contains('rotated')) {
      logo.classes.remove('rotated');
    } else {
    logo.classes.add('rotated');
    }
  });
}
''';

final String htmlCode = r'''
<img id="logo" alt="example image" src="https://dartpad.dev/dart-192.png" />
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
p {
  color: white;
  font-family: Arial, Helvetica, sans-serif;
}
#logo {
  cursor: pointer;
  transform: rotate(0deg);
  transition: transform 400ms ease-in-out;
}
#logo.rotated {
  transform: rotate(360deg);
}

''';

final String flutterCode = r'''
import 'package:flutter_web/material.dart';
import 'package:flutter_web_ui/ui.dart' as ui;

final Color darkBlue = Color.fromARGB(255, 28, 40, 52);

void main() async {
  await ui.webOnlyInitializePlatform();

  runApp(
    MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: darkBlue),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  AnimationController controller;
  Animation<double> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      duration: Duration(milliseconds: 700),
      vsync: this,
    );

    animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    ).drive(Tween(begin: 0, end: 1));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        controller
          ..reset()
          ..forward();
      },
      child: Center(
        child: RotationTransition(
          turns: animation,
          child: FlutterLogo(size: 192),
        ),
      ),
    );
  }
}
''';
