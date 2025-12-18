import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart' hide Timer;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../../services/bluetooth_service.dart';
import '../../../services/telemetry_data.dart';
import '../../pets/pet_stats.dart';
import 'flappy_pet.dart';
import 'flappy_food.dart';
import 'pipe_pair.dart';

/// Flappy Bird-style minigame using motion input from IMU sensor.
/// Falls back to tap-to-jump when no device connected (uses food sprite).
class FlappyBirdGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  final BluetoothService bluetoothService;
  final PetStats petStats;
  final VoidCallback onGameOver;
  
  /// Jump threshold in g (magnitude of acceleration vector)
  double jumpThreshold;
  
  /// Coin divisor (silver coins = score / divisor)
  final int coinDivisor;
  
  /// Whether device is connected (determines pet vs food sprite)
  bool isDeviceConnected;
  
  // Game state
  int score = 0;
  bool isGameOver = false;
  bool hasStarted = false;
  int _scoreMultiplier = 1; // Progressive scoring for motion controls
  
  // Components
  late dynamic _player; // FlappyPet or FlappyFood
  StreamSubscription<List<int>>? _telemetrySub;
  Timer? _pipeSpawnTimer;
  
  // Physics
  static const double gravity = 800.0;
  static const double flapVelocity = -300.0;
  static const double pipeSpeed = 120.0; // Slower pipes
  static const double pipeSpawnInterval = 3.0; // More time between pipes
  
  // Layout
  static const double groundHeight = 50.0;
  static const double pipeGap = 200.0; // Wider gap for easier gameplay
  
  // Debounce for motion input
  DateTime? _lastFlapTime;
  static const Duration flapCooldown = Duration(milliseconds: 300);

  FlappyBirdGame({
    required this.bluetoothService,
    required this.petStats,
    required this.onGameOver,
    this.jumpThreshold = 1.5,
    this.coinDivisor = 1,
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
    add(_player as Component);
    
    // Add ground
    add(Ground(size: Vector2(size.x, groundHeight), position: Vector2(0, size.y - groundHeight)));
    
    // Add score display
    add(ScoreDisplay(game: this));
    
    // Subscribe to raw telemetry if connected
    if (isDeviceConnected) {
      _telemetrySub = bluetoothService.incomingRaw$.listen(
        (bytes) {
          final data = TelemetryData.fromBytes(bytes);
          if (data != null) {
            _onTelemetry(data);
          }
        },
        onError: (e) => print('[FlappyBird] Telemetry stream error: $e'),
      );
    }
  }

  void _onTelemetry(TelemetryData data) {
    if (isGameOver || !hasStarted) return;
    
    // Check if magnitude exceeds threshold
    if (data.magnitude > jumpThreshold) {
      _tryFlap();
    }
  }
  
  void _tryFlap() {
    final now = DateTime.now();
    if (_lastFlapTime != null && now.difference(_lastFlapTime!) < flapCooldown) {
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
    
    // Start spawning pipes
    _spawnPipe();
    _pipeSpawnTimer = Timer.periodic(
      Duration(milliseconds: (pipeSpawnInterval * 1000).toInt()),
      (_) => _spawnPipe(),
    );
  }
  
  void _spawnPipe() {
    if (isGameOver) return;
    
    final random = Random();
    final minY = size.y * 0.2;
    final maxY = size.y * 0.7 - groundHeight;
    final gapY = minY + random.nextDouble() * (maxY - minY);
    
    add(PipePair(
      gapY: gapY,
      gapHeight: pipeGap,
      speed: pipeSpeed,
      onScore: () {
        if (!isGameOver) {
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
    )..position = Vector2(size.x + 50, 0));
  }

  void endGame() {
    if (isGameOver) return;
    isGameOver = true;
    _pipeSpawnTimer?.cancel();
    _telemetrySub?.cancel();
    
    // Award silver coins
    final coins = score ~/ coinDivisor;
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
    _telemetrySub?.cancel();
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

/// Score display component
class ScoreDisplay extends PositionComponent {
  final FlappyBirdGame game;
  
  ScoreDisplay({required this.game}) : super(position: Vector2(20, 20));

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
