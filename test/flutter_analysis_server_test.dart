// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.flutter_analyzer_server_test;

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/analysis_server.dart';
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/common_server_api.dart';
import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/protos/dart_services.pbserver.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:test/test.dart';

const counterApp = r'''
// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
''';

const draggableAndPhysicsApp = '''
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PhysicsCardDragDemo(),
    ),
  );
}

class PhysicsCardDragDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('A draggable card!'),
      ),
      body: DraggableCard(
        child: FlutterLogo(
          size: 128,
        ),
      ),
    );
  }
}

class DraggableCard extends StatefulWidget {
  final Widget child;
  DraggableCard({this.child});

  @override
  _DraggableCardState createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Alignment _dragAlignment = Alignment.center;
  Animation<Alignment> _animation;

  void _runAnimation(Offset pixelsPerSecond, Size size) {
    _animation = _controller.drive(
      AlignmentTween(
        begin: _dragAlignment,
        end: Alignment.center,
      ),
    );

    final unitsPerSecondX = pixelsPerSecond.dx / size.width;
    final unitsPerSecondY = pixelsPerSecond.dy / size.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;

    const spring = SpringDescription(
      mass: 30,
      stiffness: 1,
      damping: 1,
    );

    final simulation = SpringSimulation(spring, 0, 1, -unitVelocity);

    _controller.animateWith(simulation);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    _controller.addListener(() {
      setState(() {
        _dragAlignment = _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onPanDown: (details) {
        _controller.stop();
      },
      onPanUpdate: (details) {
        setState(() {
          _dragAlignment += Alignment(
            details.delta.dx / (size.width / 2),
            details.delta.dy / (size.height / 2),
          );
        });
      },
      onPanEnd: (details) {
        _runAnimation(details.velocity.pixelsPerSecond, size);
      },
      child: Align(
        alignment: _dragAlignment,
        child: Card(
          child: widget.child,
        ),
      ),
    );
  }
}
''';

void main() => defineTests();

void defineTests() {
  group('Flutter SDK analysis_server', () {
    AnalysisServerWrapper analysisServer;
    FlutterWebManager flutterWebManager;

    setUp(() async {
      await SdkManager.flutterSdk.init();
      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
      await flutterWebManager.warmup();
      analysisServer = FlutterAnalysisServerWrapper(flutterWebManager);
      await analysisServer.init();
      await analysisServer.warmup();
    });

    tearDown(() async {
      await analysisServer.shutdown();
      await flutterWebManager.dispose();
    });

    test('analyze counter app', () async {
      final results = await analysisServer.analyze(counterApp);
      expect(results.issues, isEmpty);
    });

    test('analyze Draggable Physics sample', () async {
      final results = await analysisServer.analyze(draggableAndPhysicsApp);
      expect(results.issues, isEmpty);
    });
  });

  group('Flutter SDK analysis_server with analysis servers', () {
    AnalysisServersWrapper analysisServersWrapper;

    setUp(() async {
      await SdkManager.flutterSdk.init();

      analysisServersWrapper = AnalysisServersWrapper();
      await analysisServersWrapper.warmup();
    });

    tearDown(() async {
      await analysisServersWrapper.shutdown();
    });

    test('analyze counter app', () async {
      final results = await analysisServersWrapper.analyze(counterApp);
      expect(results.issues, isEmpty);
    });

    test('analyze Draggable Physics sample', () async {
      final results =
          await analysisServersWrapper.analyze(draggableAndPhysicsApp);
      expect(results.issues, isEmpty);
    });
  });

  group('CommonServerImpl flutter analyze', () {
    CommonServerImpl commonServerImpl;

    _MockContainer container;
    _MockCache cache;

    setUp(() async {
      await SdkManager.flutterSdk.init();
      container = _MockContainer();
      cache = _MockCache();
      commonServerImpl = CommonServerImpl(container, cache);
      await commonServerImpl.init();
    });

    tearDown(() async {
      await commonServerImpl.shutdown();
    });

    test('counter app', () async {
      final results =
          await commonServerImpl.analyze(SourceRequest()..source = counterApp);
      expect(results.issues, isEmpty);
    });

    test('Draggable Physics sample', () async {
      final results = await commonServerImpl
          .analyze(SourceRequest()..source = draggableAndPhysicsApp);
      expect(results.issues, isEmpty);
    });
  });
}

class _MockContainer implements ServerContainer {
  @override
  String get version => vmVersion;
}

class _MockCache implements ServerCache {
  @override
  Future<String> get(String key) => Future.value(null);

  @override
  Future set(String key, String value, {Duration expiration}) => Future.value();

  @override
  Future remove(String key) => Future.value();

  @override
  Future<void> shutdown() => Future.value();
}
