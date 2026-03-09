import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'sbr_game.dart';
import 'ball.dart';
import 'power_up.dart';

enum BrickType { standard, strong, indestructible, glass, exploding, multiball, expand, ghost }

class Brick extends PositionComponent with CollisionCallbacks {
  final SBRGame game;
  BrickType type;
  int hp;
  
  Brick({
    required Vector2 position,
    required Vector2 size,
    required this.game,
    this.type = BrickType.standard,
    this.hp = 1,
  }) : super(
         position: position,
         size: size,
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  factory Brick.generateRandom(int level, Vector2 position, Vector2 size, SBRGame game) {
    final rand = Random();
    final p = rand.nextDouble();
    
    BrickType t = BrickType.standard;
    int h = 1;

    // Higher level = better chance for rare bricks
    // Base chances
    if (p < 0.05 + (level * 0.01)) {
      t = BrickType.multiball;
    } else if (p < 0.10 + (level * 0.01)) {
      t = BrickType.expand;
    } else if (p < 0.15 + (level * 0.01)) {
      t = BrickType.exploding;
    } else if (p < 0.20 + (level * 0.01)) {
      t = BrickType.glass; // Piercing
    } else if (p < 0.25 + (level * 0.01)) {
      t = BrickType.ghost;
    } else if (p < 0.40) {
      t = BrickType.strong;
      h = 2 + (level ~/ 5); // scales with level
    } else if (p < 0.45 && level > 2) {
      t = BrickType.indestructible;
    }

    return Brick(position: position, size: size, game: game, type: t, hp: h);
  }

  void hit(Ball ball) {
    if (type == BrickType.indestructible) return;

    hp--;
    
    if (hp <= 0 || ball.state == BallState.piercing) {
      destroy(byExplosion: false, triggeringBall: ball);
    }
  }

  void destroy({required bool byExplosion, Ball? triggeringBall}) {
    if (parent == null || type == BrickType.indestructible) return;
    
    removeFromParent();
    game.onBrickDestroyed();
    
    if (!byExplosion) {
      game.onBrickHitIncrementCombo();
    }

    // Trigger special abilities OR drop powerups
    switch (type) {
      case BrickType.exploding:
        _explode();
        break;
      case BrickType.glass:
        triggeringBall?.setPiercing(5.0); // 5 seconds of piercing
        break;
      case BrickType.ghost:
        triggeringBall?.setGhost();
        break;
      case BrickType.multiball:
        triggeringBall?.split(min(2 + game.currentLevel ~/ 3, 4)); // max 4 splits
        break;
      case BrickType.expand:
        _dropPowerUp(PowerUpType.expand);
        break;
      default:
        break;
    }
  }

  void _explode() {
    // 3x3 blast radius based on level (could be 4x4 or 5x5)
    // Radius = diagonal size of a brick roughly * 1.5
    final blastRadius = size.length * 1.5 * (1 + min(game.currentLevel / 5, 2.0));
    
    final allBricks = game.children.whereType<Brick>().toList();
    for (var brick in allBricks) {
      if (brick != this && brick.position.distanceTo(position) <= blastRadius) {
        brick.destroy(byExplosion: true);
      }
    }
  }

  void _dropPowerUp(PowerUpType pType) {
    final powerUp = PowerUp(
      position: position.clone(),
      game: game,
      type: pType,
    );
    game.add(powerUp);
  }

  @override
  void render(Canvas canvas) {
    Color c = Colors.white;
    switch (type) {
      case BrickType.standard:
        c = Colors.redAccent;
        break;
      case BrickType.strong:
        c = Colors.orange; // Darkens based on HP in real polish
        break;
      case BrickType.indestructible:
        c = Colors.grey;
        break;
      case BrickType.glass:
        c = Colors.lightBlueAccent.withValues(alpha: 0.5);
        break;
      case BrickType.exploding:
        c = Colors.red[900]!;
        break;
      case BrickType.multiball:
        c = Colors.greenAccent;
        break;
      case BrickType.expand:
        c = Colors.yellowAccent;
        break;
      case BrickType.ghost:
        c = Colors.purple.withValues(alpha: 0.5);
        break;
    }

    final paint = Paint()
      ..color = c
      ..style = PaintingStyle.fill;
      
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), borderPaint);
  }
}
