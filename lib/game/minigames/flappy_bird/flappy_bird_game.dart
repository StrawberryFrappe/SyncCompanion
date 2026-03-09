import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart' hide Timer;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../../services/device/device_service.dart';

import '../../pets/pet_stats.dart';
import 'flappy_difficulty.dart';
import 'flappy_pet.dart';
import 'flappy_food.dart';
import 'pipe_pair.dart';

/// Flappy Bird-style minigame using motion input from IMU sensor.
/// Falls back to tap-to-jump when no device connected (uses food sprite).
class FlappyBirdGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  final DeviceService deviceService;
  final PetStats petStats;
  final VoidCallback onGameOver;
  final FlappyDifficultyConfig difficultyConfig;
  
  /// Jump threshold - now handled in DeviceService, but we can set it
  double jumpThreshold;
  
  /// Whether device is connected (determines pet vs food sprite)
  bool isDeviceConnected;
  
  // Game state
  int score = 0;
  bool isGameOver = false;
  bool hasStarted = false;
  int _scoreMultiplier = 1; // Progressive scoring for motion controls
  double currentSpeedMultiplier = 1.0; // Progressive speed
  double? _lastGapY; // For gap generation constraints
  
  // Components
  late dynamic _player; // FlappyPet or FlappyFood
  StreamSubscription<DeviceEvent>? _eventSub;
  Timer? _pipeSpawnTimer;
  
  // Screen-relative physics (values as % of screen height/width)
  // These getters compute values based on actual screen size
  double get gravity => size.y * 1.2; // Falls across screen in ~1.3s
  double get flapVelocity => size.y * -0.45; // Jumps about 45% of screen height
  double get pipeSpeed => (size.x * difficultyConfig.pipeSpeedFactor) * currentSpeedMultiplier;
  
  // Screen-relative layout
  double get groundHeight => size.y * 0.06; // 6% of screen height
  double get pipeGap => size.y * difficultyConfig.pipeGap;
  double get playerSize => size.y * 0.08; // 8% of screen height
  
  // Debounce for motion input
  DateTime? _lastFlapTime;

  FlappyBirdGame({
    required this.deviceService,
    required this.petStats,
    required this.onGameOver,
    required this.difficultyConfig,
    this.jumpThreshold = 1.5,
    this.isDeviceConnected = false,
  });

  @override
  Color backgroundColor() => const Color(0xFF87CEEB); // Sky blue

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Create player based on connection status
    if (isDeviceConnected) {
      _player = FlappyPet(petStats: petStats);
    } else {
      _player = FlappyFood();
    }
    
    _player.position = Vector2(size.x * 0.25, size.y * 0.5);
    _player.size = Vector2(playerSize, playerSize * 1.16); // Maintain aspect ratio
    add(_player as Component);
    
    // Add ground
    add(Ground(size: Vector2(size.x, groundHeight), position: Vector2(0, size.y - groundHeight)));
    
    // Add score display
    add(ScoreDisplay(game: this));
    
    // Subscribe to events if connected
    if (isDeviceConnected) {
      // Set the threshold in service
      deviceService.updateShakeThreshold(jumpThreshold);
      
      _eventSub = deviceService.events$.listen(
        _onDeviceEvent,
        onError: (e) => print('[FlappyBird] Event stream error: $e'),
      );
      
      // Request native status to ensure telemetry stream receives fresh data.
      // This fixes motion controls not responding on first connect or reconnect
      // because broadcast streams don't replay past events to new subscribers.
      deviceService.requestNativeStatus();
    }
  }

  void _onDeviceEvent(DeviceEvent event) {
    if (isGameOver || !hasStarted) return;
    
    if (event is ShakeEvent) {
      _tryFlap();
    }
  }
  
  void _tryFlap() {
    final now = DateTime.now();
    if (_lastFlapTime != null && now.difference(_lastFlapTime!) < difficultyConfig.flapCooldown) {
      return; // Debounce
    }
    _lastFlapTime = now;
    _player.flap(flapVelocity);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (isGameOver) return;
    
    if (!hasStarted) {
      startGame();
      return;
    }
    
    // Tap to flap (always available as fallback)
    _tryFlap();
  }

  void startGame() {
    hasStarted = true;
    _player.velocity = 0.0;
    currentSpeedMultiplier = 1.0; // Reset speed
    _lastGapY = null; // Reset gap tracking
    
    // Start spawning pipes
    _spawnPipe();
  }

  void _scheduleNextPipe() {
    if (isGameOver) return;

    // Calculate dynamic interval
    // Reduce interval slightly as speed increases to make game harder
    // factor 0.25 ensures we "undercompensate" the speed increase (so gaps still grow, but slower)
    final adjustedInterval = difficultyConfig.spawnInterval / pow(currentSpeedMultiplier, 0.25);
    
    _pipeSpawnTimer = Timer(
      Duration(milliseconds: (adjustedInterval * 1000).toInt()),
      () => _spawnPipe(),
    );
  }
  
  void _spawnPipe() {
    if (isGameOver) return;
    
    final random = Random();
    final minY = size.y * 0.2;
    final maxY = size.y * 0.7 - groundHeight;
    
    double gapY;
    if (_lastGapY == null) {
      gapY = minY + random.nextDouble() * (maxY - minY);
    } else {
      final maxDev = size.y * difficultyConfig.maxGapYDeviation;
      final devMin = max(minY, _lastGapY! - maxDev);
      final devMax = min(maxY, _lastGapY! + maxDev);
      gapY = devMin + random.nextDouble() * (devMax - devMin);
    }
    _lastGapY = gapY;
    
    add(PipePair(
      gapY: gapY,
      gapHeight: pipeGap,
      groundHeight: groundHeight,
      onScore: () {
        if (!isGameOver) {
          // Increase speed based on difficulty ramp, capped to max multiplier
          currentSpeedMultiplier = (currentSpeedMultiplier * difficultyConfig.speedRamp)
              .clamp(1.0, difficultyConfig.maxSpeedMultiplier);
          
          // Progressive scoring for motion controls
          if (isDeviceConnected) {
            score += _scoreMultiplier;
            _scoreMultiplier++; // Increase multiplier for next pipe
          } else {
            score++;
          }
        }
      },
      onCollision: endGame,
    )..position = Vector2(size.x + size.x * 0.05, 0)); // 5% offset
    
    _scheduleNextPipe();
  }

  void endGame() {
    if (isGameOver) return;
    isGameOver = true;
    _pipeSpawnTimer?.cancel();
    _eventSub?.cancel();
    
    // Award silver coins
    final coins = (score * difficultyConfig.coinMultiplier).toInt();
    if (coins > 0) {
      petStats.addSilver(coins);
    }
    
    onGameOver();
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (!hasStarted || isGameOver) return;
    
    // Apply gravity
    _player.velocity += gravity * dt;
    _player.position.y += _player.velocity * dt;
    
    // Rotation based on velocity
    _player.angle = (_player.velocity / 500).clamp(-0.5, 0.5);
    
    // Check bounds
    if (_player.position.y < 0 || _player.position.y > size.y - groundHeight) {
      endGame();
    }
  }

  @override
  void onRemove() {
    _pipeSpawnTimer?.cancel();
    _eventSub?.cancel();
    super.onRemove();
  }
}

/// Ground component (visual only, collision handled in update)
class Ground extends PositionComponent {
  Ground({required Vector2 size, required Vector2 position})
      : super(size: size, position: position);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF8B4513), // Brown
    );
  }
}

class ScoreDisplay extends PositionComponent {
  final FlappyBirdGame game;
  
  ScoreDisplay({required this.game}) : super(position: Vector2(20, 20), priority: 100);

  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${game.score}',
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 48,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(offset: Offset(2, 2), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
  }
}
