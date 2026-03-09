import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../../pets/pet_stats.dart';
import '../flappy_bird/flappy_pet.dart' as flappy_pet; // Reusing sprite logic
import '../flappy_bird/flappy_food.dart' as flappy_food; // Reusing sprite logic

import 'sbr_game.dart';
import 'bumper.dart';
import 'brick.dart';

enum BallState { normal, piercing, ghost }

class Ball extends PositionComponent with CollisionCallbacks {
  final SBRGame game;
  final bool isPetSprite;
  final PetStats petStats;
  
  Vector2 velocity = Vector2.zero();
  double speed = 300; // base speed
  double radius = 12.5;
  
  BallState state = BallState.normal;
  bool isRainbowTrail = false;
  
  // Powerup timers
  double _piercingTimer = 0;
  
  late Component spriteComponent;

  Ball({
    required this.game,
    required this.isPetSprite,
    required this.petStats,
  }) : super(
         size: Vector2(20, 20),
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Add sprite based on connection
    if (isPetSprite) {
      spriteComponent = flappy_pet.FlappyPet(petStats: petStats)
        ..size = Vector2(radius * 3, radius * 3)
        ..anchor = Anchor.center;
    } else {
      spriteComponent = flappy_food.FlappyFood()
        ..size = Vector2(radius * 2, radius * 2)
        ..anchor = Anchor.center;
    }
    
    add(spriteComponent);
    add(CircleHitbox(radius: radius));
  }

  void launch() {
    // Launch upwards with slightly random angle
    final angle = -pi / 2 + (Random().nextDouble() - 0.5) * 0.5; // -90 deg +/- 15 deg
    velocity = Vector2(cos(angle), sin(angle)) * speed;
  }

  void split(int count) {
    for (int i = 0; i < count; i++) {
      final newBall = Ball(
        game: game, 
        isPetSprite: isPetSprite, 
        petStats: petStats
      );
      
      newBall.position = position.clone();
      
      // Calculate spread angle
      final angleSpread = pi / 4; // 45 degrees
      final spreadStep = angleSpread / count;
      final baseAngle = atan2(velocity.y, velocity.x);
      
      final currentAngle = baseAngle - (angleSpread / 2) + (spreadStep * i);
      
      newBall.velocity = Vector2(cos(currentAngle), sin(currentAngle)) * velocity.length;
      newBall.state = state; // inherit state
      
      game.add(newBall);
      game.activeBalls.add(newBall);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (!game.hasStarted || game.isGameOver) return;
    
    // Powerup Timers
    if (state == BallState.piercing) {
      _piercingTimer -= dt;
      if (_piercingTimer <= 0) {
        state = BallState.normal;
      }
    }

    // Move ball
    position += velocity * dt;

    // Spin sprite 
    if (spriteComponent is PositionComponent) {
      (spriteComponent as PositionComponent).angle += (velocity.length * dt) * 0.01;
    }

    // Screen bounds bounce
    if (position.x - radius < 0) {
      velocity.x = velocity.x.abs();
      position.x = radius;
    } else if (position.x + radius > game.size.x) {
      velocity.x = -velocity.x.abs();
      position.x = game.size.x - radius;
    }
    
    // Ceiling bounce
    if (position.y - radius < 0) {
      velocity.y = velocity.y.abs();
      position.y = radius;
      
      // If Ghost ball hits ceiling, return to normal
      if (state == BallState.ghost) {
        state = BallState.normal;
      }
      
    } else if (position.y + radius > game.size.y) {
      // Fell through bottom
      game.onBallFell(this);
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    if (other is Bumper) {
      _handleBumperCollision(other);
    } else if (other is Brick) {
      _handleBrickCollision(other, intersectionPoints);
    } else if (other is Ball) {
      _handleBallCollision(other);
    }
  }

  void _handleBumperCollision(Bumper bumper) {
    // Bounce off bumper
    // Adjust angle based on where it hit bumper
    final ballX = position.x;
    final bumperX = bumper.position.x;
    
    final hitFactor = (ballX - bumperX) / (bumper.size.x / 2);
    // hitFactor: -1 (left edge) to 1 (right edge)
    
    // Max bounce angle 60 degrees
    final maxAngle = pi / 3;
    final bounceAngle = hitFactor * maxAngle;
    
    // Velocity always points UP (-y) after hitting bumper
    final speed = velocity.length;
    velocity = Vector2(sin(bounceAngle), -cos(bounceAngle)) * speed;
    
    // Reset combo
    game.resetCombo();
  }

  void _handleBrickCollision(Brick brick, Set<Vector2> intersectionPoints) {
    // 1. Process Brick effect / destruction
    if (state != BallState.ghost) {
      brick.hit(this);
      
      // Don't bounce if piercing and brick is destructible
      if (state == BallState.piercing && brick.type != BrickType.indestructible) {
         return; 
      }
    } else {
      // Ghost and Piercing special logic from requirements = no bounce
      return; 
    }

    // 2. Physical bounce
    if (intersectionPoints.isEmpty) return;

    // Simple AABB collision response based on center points
    // Determine whether to reverse X or Y velocity based on overlap
    
    final bCenter = position;
    final brCenter = brick.position;
    
    final dx = bCenter.x - brCenter.x;
    final dy = bCenter.y - brCenter.y;
    
    // Normalize differences by the half-sizes
    final normDx = dx / (brick.size.x / 2);
    final normDy = dy / (brick.size.y / 2);

    if (normDx.abs() > normDy.abs()) {
      // Hit left or right side
      velocity.x = dx > 0 ? velocity.x.abs() : -velocity.x.abs();
    } else {
      // Hit top or bottom
      velocity.y = dy > 0 ? velocity.y.abs() : -velocity.y.abs();
    }
  }

  void _handleBallCollision(Ball other) {
    // Simple elastic collision swapping velocities (assuming same mass)
    final temp = velocity.clone();
    velocity = other.velocity;
    other.velocity = temp;
  }
  
  void setPiercing(double duration) {
    state = BallState.piercing;
    _piercingTimer = duration;
  }
  
  void setGhost() {
    state = BallState.ghost; // Unset when hitting ceiling
  }
}
