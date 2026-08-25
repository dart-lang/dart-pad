// Copyright 2024 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game.dart';

class Paddle extends PositionComponent with DragCallbacks, HasGameReference<BrickBreaker>, KeyboardHandler {
  Paddle({
    required this.cornerRadius,
    required super.position,
    required super.size,
  }) : super(anchor: Anchor.center, children: [RectangleHitbox()]);

  final Radius cornerRadius;

  final _paint = Paint()
    ..color = const Color(0xff1e6091)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);

    final keysPressed = HardwareKeyboard.instance.logicalKeysPressed;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) || keysPressed.contains(LogicalKeyboardKey.keyA)) {
      position.x = (position.x - (dt * 500)).clamp(
        width / 2,
        game.width - width / 2,
      );
    } else if (keysPressed.contains(LogicalKeyboardKey.arrowRight) || keysPressed.contains(LogicalKeyboardKey.keyD)) {
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
    if (isRemoved) {
      return;
    }
    super.onDragUpdate(event);
    position.x = (position.x + event.localDelta.x).clamp(
      width / 2,
      game.width - width / 2,
    );
  }
}
