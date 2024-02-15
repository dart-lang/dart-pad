// Copyright 2019 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';

const Color primaryColor = Colors.orange;

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
  double seeds = 100.0;

  int get seedCount => seeds.floor();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData().copyWith(
        platform: TargetPlatform.android,
        brightness: Brightness.dark,
        sliderTheme: SliderThemeData.fromPrimaryColors(
          primaryColor: primaryColor,
          primaryColorLight: primaryColor,
          primaryColorDark: primaryColor,
          valueIndicatorTextStyle: const DefaultTextStyle.fallback().style,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Sunflower'),
        ),
        drawer: Drawer(
          child: ListView(
            children: const [
              DrawerHeader(
                child: Center(
                  child: Text(
                    'Sunflower 🌻',
                    style: TextStyle(fontSize: 32),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: CustomPaint(
                    painter: SunflowerPainter(seedCount),
                  ),
                );
              }),
            ),
            Text('Showing $seedCount seeds'),
            ConstrainedBox(
              constraints: const BoxConstraints.tightFor(width: 300),
              child: Slider.adaptive(
                min: 20,
                max: 2000,
                value: seeds,
                onChanged: (newValue) {
                  setState(() {
                    seeds = newValue;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SunflowerPainter extends CustomPainter {
  static const seedRadius = 2.0;
  static const tau = math.pi * 2;
  static final phi = (math.sqrt(5) + 1) / 2;

  final int seeds;

  SunflowerPainter(this.seeds);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleFactor = 4 * size.shortestSide / 400;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (var i = 0; i < seeds; i++) {
      final theta = i * tau / phi;
      final r = math.sqrt(i) * scaleFactor;
      final x = centerX + r * math.cos(theta);
      final y = centerY - r * math.sin(theta);
      final offset = Offset(x, y);
      if (!size.contains(offset)) {
        continue;
      }
      drawSeed(canvas, x, y);
    }
  }

  @override
  bool shouldRepaint(SunflowerPainter oldDelegate) {
    return oldDelegate.seeds != seeds;
  }

  // Draw a small circle representing a seed centered at (x,y).
  void drawSeed(Canvas canvas, double x, double y) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.fill
      ..color = primaryColor;
    canvas.drawCircle(Offset(x, y), seedRadius, paint);
  }
}
