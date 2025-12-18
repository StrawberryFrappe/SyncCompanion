import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// A pair of pipes (top and bottom) with a gap for the player to pass through.
class PipePair extends PositionComponent with HasGameReference {
  final double gapY;
  final double gapHeight;
  final double speed;
  final double groundHeight;
  final VoidCallback onScore;
  final VoidCallback onCollision;
  
  bool _scored = false;
  double get pipeWidth => game.size.x * 0.16; // 16% of screen width (doubled for mobile visibility)
  static const Color pipeColor = Color(0xFF228B22); // Forest green

  PipePair({
    required this.gapY,
    required this.gapHeight,
    required this.speed,
    required this.groundHeight,
    required this.onScore,
    required this.onCollision,
  }) : super();

  late final RectangleComponent topPipe;
  late final RectangleComponent bottomPipe;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    size = Vector2(pipeWidth, 0);
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
    final bottomHeight = screenHeight - bottomY - groundHeight;
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
      // Use circular hitbox with ~58% radius for ~1/3 collision area (more forgiving)
      final playerCenter = player.position; // Already centered due to Anchor.center
      final hitboxRadius = (player.size.x / 2) * 0.58; // sqrt(1/3) ≈ 0.58 for 1/3 area
      
      final topPipeBottom = gapY - gapHeight / 2;
      final bottomPipeTop = gapY + gapHeight / 2;
      
      // Check if circle overlaps with top pipe (extends from y=0 to topPipeBottom)
      final nearestTopY = playerCenter.y.clamp(0, topPipeBottom);
      final nearestTopX = playerCenter.x.clamp(position.x, position.x + pipeWidth);
      final distToTop = (playerCenter - Vector2(nearestTopX, nearestTopY)).length;
      
      // Check if circle overlaps with bottom pipe (extends from bottomPipeTop to screen bottom)
      final nearestBottomY = playerCenter.y.clamp(bottomPipeTop, game.size.y);
      final nearestBottomX = playerCenter.x.clamp(position.x, position.x + pipeWidth);
      final distToBottom = (playerCenter - Vector2(nearestBottomX, nearestBottomY)).length;
      
      if (distToTop < hitboxRadius || distToBottom < hitboxRadius) {
        onCollision();
      }
    }
  }
}
