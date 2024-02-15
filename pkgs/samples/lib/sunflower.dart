// Copyright 2019 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Sunflower'),
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
            Container(
              constraints: const BoxConstraints.tightFor(width: 300),
              padding: const EdgeInsets.only(bottom: 12),
              child: Slider(
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
  static const Color primaryColor = Colors.orange;
  static const double seedRadius = 2.0;
  static const double tau = math.pi * 2;
  static final double phi = (math.sqrt(5) + 1) / 2;

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

  void drawSeed(Canvas canvas, double x, double y) {
    // Draw a small circle representing a seed centered at (x,y).
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.fill
      ..color = primaryColor;
    canvas.drawCircle(Offset(x, y), seedRadius, paint);
  }
}
