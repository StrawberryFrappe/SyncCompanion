import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'sbr_game.dart';
import 'bumper.dart';

enum PowerUpType { expand } 

class PowerUp extends PositionComponent with CollisionCallbacks {
  final SBRGame game;
  final PowerUpType type;
  
  final double fallSpeed = 150;

  PowerUp({
    required Vector2 position,
    required this.game,
    required this.type,
  }) : super(
         position: position,
         size: Vector2(24, 24),
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.isGameOver) return;

    position.y += fallSpeed * dt;

    if (position.y > game.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    if (other is Bumper) {
      _activate();
      removeFromParent();
    }
  }
  
  void _activate() {
    if (type == PowerUpType.expand) {
      game.bumper.expand(1.3); // Increase size by 30% (3 needed for rainbow)
    }
  }

  @override
  void render(Canvas canvas) {
    Color c;
    switch (type) {
      case PowerUpType.expand:
        c = Colors.yellow;
        break;
    }

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()..color = c,
    );
  }
}
