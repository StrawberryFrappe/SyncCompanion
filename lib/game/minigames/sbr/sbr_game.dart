import 'dart:async';
import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../../services/device/device_service.dart';
import '../../pets/pet_stats.dart';

import 'ball.dart';
import 'brick.dart';
import 'bumper.dart';
import 'power_up.dart';

/// SBR minigame main Game class.
class SBRGame extends FlameGame with HasCollisionDetection, TapCallbacks, DragCallbacks {
  final DeviceService deviceService;
  final PetStats petStats;
  final VoidCallback onGameOver;
  final VoidCallback? onStateChanged;
  final bool isDeviceConnected;
  
  // Game State
  int score = 0;
  int lives = 3;
  int currentLevel = 1;
  int combo = 0;
  bool isGameOver = false;
  bool hasStarted = false;
  
  late Bumper bumper;
  
  // Track balls and bricks to know when level is cleared and when a life is lost
  final List<Ball> activeBalls = [];
  int destructibleBricksCount = 0;

  StreamSubscription<DeviceEvent>? _eventSub;
  
  SBRGame({
    required this.deviceService,
    required this.petStats,
    required this.onGameOver,
    this.isDeviceConnected = false,
    this.onStateChanged,
  });

  @override
  Color backgroundColor() => const Color(0xFF222222);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    _initBumper();
    _loadLevel(currentLevel);
    
    if (isDeviceConnected) {
      _eventSub = deviceService.events$.listen(_onDeviceEvent);
      deviceService.requestNativeStatus(); // trigger stream update
    }
  }

  void _initBumper() {
    bumper = Bumper(
      size: Vector2(size.x * 0.25, size.y * 0.02),
      position: Vector2(size.x / 2, size.y * 0.9),
      game: this,
    );
    add(bumper);
  }

  void _onDeviceEvent(DeviceEvent event) {
    if (event is ShakeEvent) {
      // TODO: Implement tilt-to-move when AngleEvent is added to DeviceService.
      // For now, shake has no effect on the bumper.
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (isGameOver) return;
    if (!hasStarted) {
      startGame();
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isDeviceConnected && hasStarted && !isGameOver) {
      // Fallback touch controls
      bumper.position.x += event.localDelta.x;
    }
  }

  void startGame() {
    hasStarted = true;
    _spawnBall(); // Start with 1 ball
    onStateChanged?.call();
  }

  void _spawnBall() {
    final ball = Ball(
      game: this,
      isPetSprite: isDeviceConnected,
      petStats: petStats,
    );
    ball.position = Vector2(bumper.position.x, bumper.position.y - ball.radius - 5);
    ball.launch();
    
    add(ball);
    activeBalls.add(ball);
  }

  void _loadLevel(int level) {
    // Clear existing bricks
    children.whereType<Brick>().forEach((b) => b.removeFromParent());
    destructibleBricksCount = 0;
    
    // Generate brick grid based on level
    final rows = min(5 + level, 10); // Max 10 rows
    final cols = min(7 + (level ~/ 2), 12); // Max 12 cols
    
    final brickWidth = size.x / cols;
    final brickHeight = size.y * 0.03;
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final position = Vector2(
          c * brickWidth + brickWidth / 2,
          r * brickHeight + brickHeight / 2 + size.y * 0.1, // Offset from top
        );
        
        final brick = Brick.generateRandom(level, position, Vector2(brickWidth * 0.9, brickHeight * 0.9), this);
        add(brick);
        if (brick.type != BrickType.indestructible) {
          destructibleBricksCount++;
        }
      }
    }
  }

  void onBrickDestroyed() {
    destructibleBricksCount--;
    if (destructibleBricksCount <= 0) {
      _levelComplete();
    }
  }
  
  void onBrickHitIncrementCombo() {
    combo++;
    score += (10 * combo); // Example scoring
    
    if (combo > 0 && combo % 50 == 0) {
      lives++;
      // TODO: Show visual +1 life popup
    }
    onStateChanged?.call();
  }

  void resetCombo() {
    combo = 0;
  }

  void _levelComplete() {
    hasStarted = false;
    currentLevel++;
    
    // Remove active balls and powerups
    for (var b in activeBalls) {
      b.removeFromParent();
    }
    activeBalls.clear();
    
    children.whereType<PowerUp>().forEach((p) => p.removeFromParent());
    
    // Reset bumper size and rainbow state for new level
    bumper.resetWidth();
    
    // Load next
    _loadLevel(currentLevel);
    onStateChanged?.call();
  }

  void onBallFell(Ball ball) {
    activeBalls.remove(ball);
    ball.removeFromParent();
    
    if (activeBalls.isEmpty) {
      loseLife();
    }
  }

  void loseLife() {
    lives--;
    resetCombo();
    bumper.resetWidth(); // Reset stacked expansions
    
    if (lives <= 0) {
      endGame();
    } else {
      hasStarted = false;
      // Waiting for tap to start again
      onStateChanged?.call();
    }
  }

  void endGame() {
    isGameOver = true;
    _eventSub?.cancel();
    
    // Award coins
    petStats.addSilver(score ~/ 100); 
    
    onStateChanged?.call();
    onGameOver();
  }

  @override
  void onRemove() {
    _eventSub?.cancel();
    super.onRemove();
  }
}
