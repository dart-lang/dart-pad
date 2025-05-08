// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This file has been automatically generated - please do not edit it manually.

import 'package:collection/collection.dart';

class Sample {
  final String category;
  final String icon;
  final String name;
  final String id;
  final String source;

  const Sample({
    required this.category,
    required this.icon,
    required this.name,
    required this.id,
    required this.source,
  });

  bool get isDart => category == 'Dart';

  bool get shouldList => category != 'Defaults';

  @override
  String toString() => '[$category] $name ($id)';
}

abstract final class Samples {
  static const List<Sample> all = [
    _fibonacci,
    _helloWorld,
    _dart,
    _flutter,
    _flameGame,
    _counter,
    _sunflower,
  ];

  static const Map<String, List<Sample>> categories = {
    'Dart': [_fibonacci, _helloWorld],
    'Flutter': [_counter, _sunflower],
    'Ecosystem': [_flameGame],
  };

  static Sample? getById(String? id) => all.firstWhereOrNull((s) => s.id == id);

  static String defaultSnippet({bool forFlutter = false}) =>
      getById(forFlutter ? 'flutter' : 'dart')!.source;
}

const _fibonacci = Sample(
  category: 'Dart',
  icon: 'dart',
  name: 'Fibonacci',
  id: 'fibonacci',
  source: r'''
void main() {
  const i = 20;

  print('fibonacci($i) = ${fibonacci(i)}');
}

/// Computes the nth Fibonacci number.
int fibonacci(int n) {
  return n < 2 ? n : (fibonacci(n - 1) + fibonacci(n - 2));
}
''',
);

const _helloWorld = Sample(
  category: 'Dart',
  icon: 'dart',
  name: 'Hello world',
  id: 'hello-world',
  source: r'''
void main() {
  for (var i = 0; i < 10; i++) {
    print('hello ${i + 1}');
  }
}
''',
);

const _dart = Sample(
  category: 'Defaults',
  icon: 'dart',
  name: 'Dart snippet',
  id: 'dart',
  source: r'''
void main() {
  for (var i = 0; i < 10; i++) {
    print('hello ${i + 1}');
  }
}
''',
);

const _flutter = Sample(
  category: 'Defaults',
  icon: 'flutter',
  name: 'Flutter snippet',
  id: 'flutter',
  source: r'''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('Hello, World!'))),
    );
  }
}
''',
);

const _flameGame = Sample(
  category: 'Ecosystem',
  icon: 'flame',
  name: 'Flame game',
  id: 'flame-game',
  source: r'''
/// A simplified brick-breaker game,
/// built using the Flame game engine for Flutter.
///
/// To learn how to build a more complete version of this game yourself,
/// check out the codelab at https://flutter.dev/to/brick-breaker.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const GameApp());
}

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  late final BrickBreaker game;

  @override
  void initState() {
    super.initState();
    game = BrickBreaker();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffa9d6e5), Color(0xfff2e8cf)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FittedBox(
                  child: SizedBox(
                    width: gameWidth,
                    height: gameHeight,
                    child: GameWidget(game: game),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrickBreaker extends FlameGame
    with HasCollisionDetection, KeyboardEvents, TapDetector {
  BrickBreaker()
    : super(
        camera: CameraComponent.withFixedResolution(
          width: gameWidth,
          height: gameHeight,
        ),
      );

  final rand = math.Random();
  double get width => size.x;
  double get height => size.y;

  @override
  FutureOr<void> onLoad() async {
    super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(PlayArea());
    startGame();
  }

  void startGame() {
    world.removeAll(world.children.query<Ball>());
    world.removeAll(world.children.query<Paddle>());
    world.removeAll(world.children.query<Brick>());

    world.add(
      Ball(
        difficultyModifier: difficultyModifier,
        radius: ballRadius,
        position: size / 2,
        velocity:
            Vector2(
                (rand.nextDouble() - 0.5) * width,
                height * 0.3,
              ).normalized()
              ..scale(height / 4),
      ),
    );

    world.add(
      Paddle(
        size: Vector2(paddleWidth, paddleHeight),
        cornerRadius: const Radius.circular(ballRadius / 2),
        position: Vector2(width / 2, height * 0.95),
      ),
    );

    world.addAll([
      for (var i = 0; i < brickColors.length; i++)
        for (var j = 1; j <= 5; j++)
          Brick(
            Vector2(
              (i + 0.5) * brickWidth + (i + 1) * brickGutter,
              (j + 2.0) * brickHeight + j * brickGutter,
            ),
            brickColors[i],
          ),
    ]);
  }

  @override
  void onTap() {
    super.onTap();
    startGame();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    super.onKeyEvent(event, keysPressed);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.enter:
        startGame();
    }
    return KeyEventResult.handled;
  }

  @override
  Color backgroundColor() => const Color(0xfff2e8cf);
}

class Ball extends CircleComponent
    with CollisionCallbacks, HasGameReference<BrickBreaker> {
  Ball({
    required this.velocity,
    required super.position,
    required double radius,
    required this.difficultyModifier,
  }) : super(
         radius: radius,
         anchor: Anchor.center,
         paint:
             Paint()
               ..color = const Color(0xff1e6091)
               ..style = PaintingStyle.fill,
         children: [CircleHitbox()],
       );

  final Vector2 velocity;
  final double difficultyModifier;

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayArea) {
      if (intersectionPoints.first.y <= 0) {
        velocity.y = -velocity.y;
      } else if (intersectionPoints.first.x <= 0) {
        velocity.x = -velocity.x;
      } else if (intersectionPoints.first.x >= game.width) {
        velocity.x = -velocity.x;
      } else if (intersectionPoints.first.y >= game.height) {
        add(
          RemoveEffect(
            delay: 0.35,
            onComplete: () {
              game.startGame();
            },
          ),
        );
      }
    } else if (other is Paddle) {
      velocity.y = -velocity.y;
      velocity.x =
          velocity.x +
          (position.x - other.position.x) / other.size.x * game.width * 0.3;
    } else if (other is Brick) {
      if (position.y < other.position.y - other.size.y / 2) {
        velocity.y = -velocity.y;
      } else if (position.y > other.position.y + other.size.y / 2) {
        velocity.y = -velocity.y;
      } else if (position.x < other.position.x) {
        velocity.x = -velocity.x;
      } else if (position.x > other.position.x) {
        velocity.x = -velocity.x;
      }
      velocity.setFrom(velocity * difficultyModifier);
    }
  }
}

class Paddle extends PositionComponent
    with DragCallbacks, HasGameReference<BrickBreaker>, KeyboardHandler {
  Paddle({
    required this.cornerRadius,
    required super.position,
    required super.size,
  }) : super(anchor: Anchor.center, children: [RectangleHitbox()]);

  final Radius cornerRadius;

  final _paint =
      Paint()
        ..color = const Color(0xff1e6091)
        ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);

    final keysPressed = HardwareKeyboard.instance.logicalKeysPressed;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA)) {
      position.x = (position.x - (dt * 500)).clamp(
        width / 2,
        game.width - width / 2,
      );
    } else if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD)) {
      position.x = (position.x + (dt * 500)).clamp(
        width / 2,
        game.width - width / 2,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size.toSize(), cornerRadius),
      _paint,
    );
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (isRemoved) return;
    super.onDragUpdate(event);
    position.x = (position.x + event.localDelta.x).clamp(
      width / 2,
      game.width - width / 2,
    );
  }
}

class Brick extends RectangleComponent
    with CollisionCallbacks, HasGameReference<BrickBreaker> {
  Brick(Vector2 position, Color color)
    : super(
        position: position,
        size: Vector2(brickWidth, brickHeight),
        anchor: Anchor.center,
        paint:
            Paint()
              ..color = color
              ..style = PaintingStyle.fill,
        children: [RectangleHitbox()],
      );

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    removeFromParent();

    if (game.world.children.query<Brick>().length == 1) {
      game.startGame();
    }
  }
}

class PlayArea extends RectangleComponent with HasGameReference<BrickBreaker> {
  PlayArea() : super(children: [RectangleHitbox()]);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(game.width, game.height);
  }
}

const brickColors = [
  Color(0xfff94144),
  Color(0xfff3722c),
  Color(0xfff8961e),
  Color(0xfff9844a),
  Color(0xfff9c74f),
  Color(0xff90be6d),
  Color(0xff43aa8b),
  Color(0xff4d908e),
  Color(0xff277da1),
  Color(0xff577590),
];

const gameWidth = 820.0;
const gameHeight = 1600.0;
const ballRadius = gameWidth * 0.02;
const paddleWidth = gameWidth * 0.2;
const paddleHeight = ballRadius * 2;
const paddleStep = gameWidth * 0.05;
const brickGutter = gameWidth * 0.015;
final brickWidth =
    (gameWidth - (brickGutter * (brickColors.length + 1))) / brickColors.length;
const brickHeight = gameHeight * 0.03;
const difficultyModifier = 1.05;
''',
);

const _counter = Sample(
  category: 'Flutter',
  icon: 'flutter',
  name: 'Counter',
  id: 'counter',
  source: r'''
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
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
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
''',
);

const _sunflower = Sample(
  category: 'Flutter',
  icon: 'flutter',
  name: 'Sunflower',
  id: 'sunflower',
  source: r'''
import 'dart:math' as math;

import 'package:flutter/material.dart';

const int maxSeeds = 250;

void main() {
  runApp(const Sunflower());
}

class Sunflower extends StatefulWidget {
  const Sunflower({super.key});

  @override
  State<StatefulWidget> createState() {
    return _SunflowerState();
  }
}

class _SunflowerState extends State<Sunflower> {
  int seeds = maxSeeds ~/ 2;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(elevation: 2),
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Sunflower')),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: SunflowerWidget(seeds)),
              const SizedBox(height: 20),
              Text('Showing ${seeds.round()} seeds'),
              SizedBox(
                width: 300,
                child: Slider(
                  min: 1,
                  max: maxSeeds.toDouble(),
                  value: seeds.toDouble(),
                  onChanged: (val) {
                    setState(() => seeds = val.round());
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class SunflowerWidget extends StatelessWidget {
  static const tau = math.pi * 2;
  static const scaleFactor = 1 / 40;
  static const size = 600.0;
  static final phi = (math.sqrt(5) + 1) / 2;
  static final rng = math.Random();

  final int seeds;

  const SunflowerWidget(this.seeds, {super.key});

  @override
  Widget build(BuildContext context) {
    final seedWidgets = <Widget>[];

    for (var i = 0; i < seeds; i++) {
      final theta = i * tau / phi;
      final r = math.sqrt(i) * scaleFactor;

      seedWidgets.add(
        AnimatedAlign(
          key: ValueKey(i),
          duration: Duration(milliseconds: rng.nextInt(500) + 250),
          curve: Curves.easeInOut,
          alignment: Alignment(r * math.cos(theta), -1 * r * math.sin(theta)),
          child: const Dot(true),
        ),
      );
    }

    for (var j = seeds; j < maxSeeds; j++) {
      final x = math.cos(tau * j / (maxSeeds - 1)) * 0.9;
      final y = math.sin(tau * j / (maxSeeds - 1)) * 0.9;

      seedWidgets.add(
        AnimatedAlign(
          key: ValueKey(j),
          duration: Duration(milliseconds: rng.nextInt(500) + 250),
          curve: Curves.easeInOut,
          alignment: Alignment(x, y),
          child: const Dot(false),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        height: size,
        width: size,
        child: Stack(children: seedWidgets),
      ),
    );
  }
}

class Dot extends StatelessWidget {
  static const size = 5.0;
  static const radius = 3.0;

  final bool lit;

  const Dot(this.lit, {super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: lit ? Colors.orange : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const SizedBox(height: size, width: size),
    );
  }
}
''',
);
