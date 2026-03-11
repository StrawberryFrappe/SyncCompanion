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
  bool _destroyed = false;
  
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

    // Higher level = slightly better chance for rare bricks
    // Reduced base chances so standard bricks dominate
    if (p < 0.02 + (level * 0.005)) {
      t = BrickType.multiball;
    } else if (p < 0.04 + (level * 0.005)) {
      t = BrickType.expand;
    } else if (p < 0.07 + (level * 0.005)) {
      t = BrickType.exploding;
    } else if (p < 0.09 + (level * 0.005)) {
      t = BrickType.glass; // Piercing
    } else if (p < 0.11 + (level * 0.005)) {
      t = BrickType.ghost;
    } else if (p < 0.25) {
      t = BrickType.strong;
      h = 2 + (level ~/ 5); // scales with level
    } else if (p < 0.28 && level > 2) {
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
    if (_destroyed || type == BrickType.indestructible) return;
    _destroyed = true;
    
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
        c = Colors.orange;
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
    
    // Draw icon for special brick types
    _renderIcon(canvas);
  }

  void _renderIcon(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final iconR = min(size.x, size.y) * 0.3;
    
    final iconPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    switch (type) {
      case BrickType.strong:
        // Draw shield icon (disappears at hp == 1)
        if (hp > 1) {
          final shieldH = iconR * 1.2;
          final shieldW = iconR * 0.9;
          final shieldPath = Path()
            ..moveTo(cx - shieldW, cy - shieldH * 0.5)
            ..lineTo(cx, cy - shieldH * 0.8)
            ..lineTo(cx + shieldW, cy - shieldH * 0.5)
            ..lineTo(cx + shieldW, cy + shieldH * 0.1)
            ..quadraticBezierTo(cx, cy + shieldH * 0.8, cx - shieldW, cy + shieldH * 0.1)
            ..close();
          canvas.drawPath(shieldPath, iconPaint);
          // Draw HP ticks inside shield
          if (hp > 2) {
            final tickPaint = Paint()
              ..color = Colors.white.withValues(alpha: 0.7)
              ..style = PaintingStyle.fill;
            for (int i = 0; i < min(hp - 1, 4); i++) {
              canvas.drawCircle(
                Offset(cx - shieldW * 0.3 + i * shieldW * 0.25, cy),
                2,
                tickPaint,
              );
            }
          }
        }
        break;
      
      case BrickType.exploding:
        // 6-pointed star
        for (int i = 0; i < 6; i++) {
          final angle = i * pi / 3;
          canvas.drawLine(
            Offset(cx, cy),
            Offset(cx + cos(angle) * iconR, cy + sin(angle) * iconR),
            iconPaint,
          );
        }
        break;
      
      case BrickType.multiball:
        // Draw 2-4 small circles based on level
        final count = min(2 + game.currentLevel ~/ 3, 4);
        final dotR = iconR * 0.3;
        final spacing = (size.x * 0.6) / (count + 1);
        final startX = size.x * 0.2;
        final fillPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        for (int i = 0; i < count; i++) {
          canvas.drawCircle(
            Offset(startX + spacing * (i + 1), cy),
            dotR,
            fillPaint,
          );
        }
        break;
      
      case BrickType.expand:
        // Double-headed horizontal arrow ↔ (dark color for yellow background)
        final expandPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        final halfLen = iconR * 0.9;
        final head = iconR * 0.4;
        // Shaft
        canvas.drawLine(Offset(cx - halfLen, cy), Offset(cx + halfLen, cy), expandPaint);
        // Left arrowhead
        canvas.drawLine(Offset(cx - halfLen, cy), Offset(cx - halfLen + head, cy - head), expandPaint);
        canvas.drawLine(Offset(cx - halfLen, cy), Offset(cx - halfLen + head, cy + head), expandPaint);
        // Right arrowhead
        canvas.drawLine(Offset(cx + halfLen, cy), Offset(cx + halfLen - head, cy - head), expandPaint);
        canvas.drawLine(Offset(cx + halfLen, cy), Offset(cx + halfLen - head, cy + head), expandPaint);
        break;
      
      case BrickType.ghost:
        // Wavy line ~
        final path = Path();
        final waveW = iconR * 1.2;
        path.moveTo(cx - waveW, cy);
        path.cubicTo(cx - waveW / 2, cy - iconR * 0.7, cx - waveW / 4, cy + iconR * 0.7, cx, cy);
        path.cubicTo(cx + waveW / 4, cy - iconR * 0.7, cx + waveW / 2, cy + iconR * 0.7, cx + waveW, cy);
        canvas.drawPath(path, iconPaint);
        break;
      
      case BrickType.glass:
        // Diamond outline ◇
        final half = iconR * 0.7;
        final diamondPath = Path()
          ..moveTo(cx, cy - half)
          ..lineTo(cx + half, cy)
          ..lineTo(cx, cy + half)
          ..lineTo(cx - half, cy)
          ..close();
        canvas.drawPath(diamondPath, iconPaint);
        break;
      
      case BrickType.indestructible:
        // X mark
        final half = iconR * 0.6;
        canvas.drawLine(Offset(cx - half, cy - half), Offset(cx + half, cy + half), iconPaint);
        canvas.drawLine(Offset(cx + half, cy - half), Offset(cx - half, cy + half), iconPaint);
        break;
      
      default:
        break; // Standard - no icon
    }
  }
}
