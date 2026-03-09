import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'sbr_game.dart';

class Bumper extends PositionComponent with CollisionCallbacks {
  final SBRGame game;
  double _baseWidth;
  
  double velocityX = 0;
  double maxSpeed = 800; // pixels per second
  bool isRainbow = false;

  Bumper({
    required Vector2 size,
    required Vector2 position,
    required this.game,
  }) : _baseWidth = size.x,
       super(
         size: size,
         position: position,
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  void setVelocityFromTilt(double tiltMultiplier) {
    // Normalizes -1.0 to 1.0 into left/right speed
    velocityX = tiltMultiplier * maxSpeed;
  }

  void expand(double multiplier) {
    size.x *= multiplier;
    
    if (size.x > game.size.x / 2 && !isRainbow) {
      _triggerRainbowEvent();
    } else if (size.x > game.size.x) {
      size.x = game.size.x;
    }
  }

  void _triggerRainbowEvent() {
    isRainbow = true;
    size.x = game.size.x; // Full screen width
    // Boost all balls
    for (var ball in game.activeBalls) {
      ball.velocity *= 2.5; 
      ball.isRainbowTrail = true;
    }
  }

  void resetWidth() {
    size.x = _baseWidth;
    isRainbow = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (!game.hasStarted || game.isGameOver) return;

    if (game.isDeviceConnected) {
      position.x += velocityX * dt;
    }

    // Clamp to screen bounds
    final halfWidth = size.x / 2;
    if (position.x - halfWidth < 0) {
      position.x = halfWidth;
    } else if (position.x + halfWidth > game.size.x) {
      position.x = game.size.x - halfWidth;
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = isRainbow ? Colors.purpleAccent : Colors.blueAccent
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(8),
      ),
      paint,
    );
  }
}
