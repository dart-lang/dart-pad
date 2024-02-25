// Copyright 2019 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';

const int maxSeeds = 500;

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
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SunflowerWidget(seeds),
              ),
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
  static const scaleFactor = 1 / 64;
  static const size = 800.0;
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

      seedWidgets.add(AnimatedAlign(
        key: ValueKey(i),
        duration: Duration(milliseconds: rng.nextInt(500) + 250),
        curve: Curves.easeInOut,
        alignment: Alignment(r * math.cos(theta), -1 * r * math.sin(theta)),
        child: const Dot(true),
      ));
    }

    for (var j = seeds; j < maxSeeds; j++) {
      final index = maxSeeds - j - 1;
      final x = (index % 80) * 0.025 - 1;
      final y = 1 - ((index / 80).floor() * 0.025);
      seedWidgets.add(AnimatedAlign(
        key: ValueKey(j),
        duration: Duration(milliseconds: rng.nextInt(500) + 250),
        curve: Curves.easeInOut,
        alignment: Alignment(x, y),
        child: const Dot(false),
      ));
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
      child: const SizedBox(
        height: size,
        width: size,
      ),
    );
  }
}
