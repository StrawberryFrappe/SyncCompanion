import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// A pair of pipes (top and bottom) with a gap for the player to pass through.
class PipePair extends PositionComponent with HasGameReference {
  final double gapY;
  final double gapHeight;
  final double speed;
  final VoidCallback onScore;
  final VoidCallback onCollision;
  
  bool _scored = false;
  static const double pipeWidth = 60.0;
  static const Color pipeColor = Color(0xFF228B22); // Forest green

  PipePair({
    required this.gapY,
    required this.gapHeight,
    required this.speed,
    required this.onScore,
    required this.onCollision,
  }) : super(size: Vector2(pipeWidth, 0));

  late final RectangleComponent topPipe;
  late final RectangleComponent bottomPipe;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    final screenHeight = game.size.y;
    
    // Top pipe: from top of screen to gap start
    final topHeight = gapY - gapHeight / 2;
    topPipe = RectangleComponent(
      size: Vector2(pipeWidth, topHeight),
      position: Vector2.zero(),
      paint: Paint()..color = pipeColor,
    );
    topPipe.add(RectangleHitbox());
    add(topPipe);
    
    // Bottom pipe: from gap end to ground
    final bottomY = gapY + gapHeight / 2;
    final bottomHeight = screenHeight - bottomY - 50; // 50 = ground height
    bottomPipe = RectangleComponent(
      size: Vector2(pipeWidth, bottomHeight),
      position: Vector2(0, bottomY),
      paint: Paint()..color = pipeColor,
    );
    bottomPipe.add(RectangleHitbox());
    add(bottomPipe);
    
    // Draw caps on pipes for visual polish
    add(RectangleComponent(
      size: Vector2(pipeWidth + 10, 20),
      position: Vector2(-5, topHeight - 20),
      paint: Paint()..color = const Color(0xFF2E8B57),
    ));
    add(RectangleComponent(
      size: Vector2(pipeWidth + 10, 20),
      position: Vector2(-5, bottomY),
      paint: Paint()..color = const Color(0xFF2E8B57),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Move left
    position.x -= speed * dt;
    
    // Check if passed (player is at x=25% of screen width)
    final playerX = game.size.x * 0.25;
    if (!_scored && position.x + pipeWidth < playerX) {
      _scored = true;
      onScore();
    }
    
    // Remove when off-screen
    if (position.x < -pipeWidth - 20) {
      removeFromParent();
    }
    
    // Check collision with player (simple AABB check)
    final players = game.children.whereType<PositionComponent>()
        .where((c) => c.runtimeType.toString().startsWith('Flappy'))
        .toList();
    final player = players.isNotEmpty ? players.first : null;
    
    if (player != null) {
      final playerRect = player.toRect();
      final topRect = Rect.fromLTWH(
        position.x, 0,
        pipeWidth, gapY - gapHeight / 2,
      );
      final bottomRect = Rect.fromLTWH(
        position.x, gapY + gapHeight / 2,
        pipeWidth, game.size.y,
      );
      
      if (playerRect.overlaps(topRect) || playerRect.overlaps(bottomRect)) {
        onCollision();
      }
    }
  }
}
