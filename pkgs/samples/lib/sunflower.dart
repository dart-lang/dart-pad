// Copyright 2019 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';

const double maxSeeds = 1000;

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
  double seeds = maxSeeds / 2;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(elevation: 2),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Sunflower'),
          elevation: 2,
        ),
        body: Column(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: CustomPaint(
                    painter: SunflowerPainter(seeds.round()),
                  ),
                );
              }),
            ),
            Text('Showing ${seeds.round()} seeds'),
            Container(
              constraints: const BoxConstraints.tightFor(width: 300),
              padding: const EdgeInsets.only(bottom: 12),
              child: Slider(
                min: 1,
                max: maxSeeds,
                value: seeds,
                onChanged: (newValue) {
                  setState(() => seeds = newValue);
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
  static const Color primaryColor = Colors.orange;
  static const double seedRadius = 2;
  static const double tau = math.pi * 2;
  static final double phi = (math.sqrt(5) + 1) / 2;

  final int seeds;

  SunflowerPainter(this.seeds);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleFactor = 5 * size.shortestSide / 375;
    final center = size.center(Offset.zero);

    for (var i = 0; i < seeds; i++) {
      final theta = i * tau / phi;
      final r = math.sqrt(i) * scaleFactor;

      drawSeed(
        canvas,
        center.dx + r * math.cos(theta),
        center.dy - r * math.sin(theta),
      );
    }
  }

  @override
  bool shouldRepaint(SunflowerPainter oldDelegate) {
    return oldDelegate.seeds != seeds;
  }

  void drawSeed(Canvas canvas, double x, double y) {
    // Draw a small circle representing a seed centered at (x,y).
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.fill
      ..color = primaryColor;
    canvas.drawCircle(Offset(x, y), seedRadius, paint);
  }
}
