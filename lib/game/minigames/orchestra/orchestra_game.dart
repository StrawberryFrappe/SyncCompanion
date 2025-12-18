import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../../services/bluetooth_service.dart';
import '../../../services/telemetry_data.dart';
import '../../pets/pet_stats.dart';
import 'pet_musician.dart';
import 'tone_player.dart';

/// Orchestra minigame where pets sing at different pitches based on touch position.
/// - Horizontal position determines pitch (smooth glide, not discrete notes)
/// - Vertical position determines volume (top = loud, bottom = quiet)
/// - Hold to sing, release to stop
/// - Multiple simultaneous touches for polyphony
class OrchestraGame extends FlameGame with MultiTouchDragDetector, MultiTouchTapDetector {
  final BluetoothService bluetoothService;
  final PetStats petStats;
  final VoidCallback onExit;
  final bool isDeviceConnected;
  
  /// Number of pets in the orchestra
  final int petCount;
  
  /// Musical frequency range (Hz)
  static const double minFrequency = 220.0; // A3
  static const double maxFrequency = 880.0; // A5
  
  // Components
  final List<PetMusician> _musicians = [];
  
  // Touch tracking: pointerId -> TonePlayer
  final Map<int, TonePlayer> _touchPlayers = {};
  // Touch tracking: pointerId -> current pet index (for visuals)
  final Map<int, int> _touchPetIndex = {};
  
  // Motion control
  StreamSubscription<List<int>>? _telemetrySub;
  TonePlayer? _motionPlayer;
  int? _motionPetIndex;
  Vector2 _calibrationOffset = Vector2.zero();
  bool _isCalibrated = false;
  
  // Motion smoothing and dead zone
  Vector2 _smoothedMotion = Vector2.zero();
  bool _motionActive = false;
  DateTime _lastMotionTime = DateTime.now();
  static const double motionThreshold = 0.1; // Minimum tilt to trigger audio
  static const Duration motionTimeout = Duration(milliseconds: 400);
  static const double smoothingFactor = 0.3; // Lower = smoother
  
  OrchestraGame({
    required this.bluetoothService,
    required this.petStats,
    required this.onExit,
    this.isDeviceConnected = false,
    this.petCount = 8,
  });
  
  @override
  Color backgroundColor() => const Color(0xFF2D1B4E); // Deep purple stage
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Calculate pet layout
    final petWidth = size.x / (petCount + 1);
    final petHeight = petWidth * 1.16; // Maintain aspect ratio
    final baseY = size.y * 0.6; // Position pets at 60% down
    
    // Create musicians (visual only - no audio attached)
    for (int i = 0; i < petCount; i++) {
      final xPos = petWidth * (i + 1);
      
      final musician = PetMusician(
        petStats: petStats,
        pitch: 0, // Not used for audio anymore
        position: Vector2(xPos, baseY),
        size: Vector2(petWidth * 0.8, petHeight * 0.8),
      );
      
      _musicians.add(musician);
      add(musician);
    }
    
    // Add title
    add(TitleDisplay(game: this));
    
    // Add exit button
    add(ExitButton(onTap: _handleExit, game: this));
    
    // Subscribe to motion controls if connected
    if (isDeviceConnected) {
      _motionPlayer = TonePlayer();
      _telemetrySub = bluetoothService.incomingRaw$.listen(
        (bytes) {
          final data = TelemetryData.fromBytes(bytes);
          if (data != null) {
            _onTelemetry(data);
          }
        },
        onError: (e) => print('[Orchestra] Telemetry error: $e'),
      );
      bluetoothService.requestNativeStatus();
    }
  }
  
  void _handleExit() {
    cleanup();
    onExit();
  }
  
  /// Calculate frequency from horizontal position (smooth interpolation)
  double _getFrequencyFromX(double x) {
    final normalized = (x / size.x).clamp(0.0, 1.0);
    // Exponential interpolation for more natural pitch perception
    final logMin = math.log(minFrequency);
    final logMax = math.log(maxFrequency);
    return math.exp(logMin + normalized * (logMax - logMin));
  }
  
  /// Get pet index from x position for visual feedback
  int _getPetIndexFromX(double x) {
    final petWidth = size.x / (petCount + 1);
    final index = (x / petWidth - 0.5).round();
    return index.clamp(0, petCount - 1);
  }
  
  double _getVolumeFromY(double y) {
    // Top of screen = loud (1.0), bottom = quiet (0.2)
    final normalized = 1.0 - (y / size.y).clamp(0.0, 1.0);
    return 0.2 + normalized * 0.8;
  }
  
  void _onTelemetry(TelemetryData data) {
    if (_motionPlayer == null) return;
    
    if (!_isCalibrated) {
      _calibrationOffset = Vector2(data.ax, data.ay);
      _smoothedMotion = Vector2.zero();
      _isCalibrated = true;
      return;
    }
    
    final relativeX = data.ax - _calibrationOffset.x;
    final relativeY = data.ay - _calibrationOffset.y;
    
    // Apply exponential moving average smoothing
    _smoothedMotion = Vector2(
      _smoothedMotion.x + smoothingFactor * (relativeX - _smoothedMotion.x),
      _smoothedMotion.y + smoothingFactor * (relativeY - _smoothedMotion.y),
    );
    
    // Check if motion exceeds the dead zone threshold
    final motionMagnitude = _smoothedMotion.length;
    
    if (motionMagnitude < motionThreshold) {
      // Below threshold - don't start new audio, existing will timeout
      return;
    }
    
    // Motion detected - update last motion time
    _lastMotionTime = DateTime.now();
    _motionActive = true;
    
    // Map to screen position
    final normalizedX = ((_smoothedMotion.x / 0.5) + 1) / 2; // 0 to 1
    final screenX = normalizedX.clamp(0.0, 1.0) * size.x;
    final screenY = ((_smoothedMotion.y / 0.5) + 1) / 2 * size.y;
    
    final frequency = _getFrequencyFromX(screenX);
    final volume = _getVolumeFromY(screenY);
    final petIndex = _getPetIndexFromX(screenX);
    
    // Update visual feedback
    if (_motionPetIndex != null && _motionPetIndex != petIndex) {
      if (_motionPetIndex! < _musicians.length) {
        _musicians[_motionPetIndex!].stopSinging();
      }
    }
    _motionPetIndex = petIndex;
    
    if (petIndex < _musicians.length) {
      _musicians[petIndex].startSinging(volume);
    }
    
    // Update audio
    _motionPlayer!.setFrequency(frequency, volume);
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Check for motion inactivity timeout
    if (_motionActive && _motionPlayer != null) {
      final elapsed = DateTime.now().difference(_lastMotionTime);
      if (elapsed > motionTimeout) {
        // Stop motion audio due to inactivity
        _motionPlayer!.stopTone();
        _motionActive = false;
        
        // Stop visual feedback
        if (_motionPetIndex != null && _motionPetIndex! < _musicians.length) {
          _musicians[_motionPetIndex!].stopSinging();
        }
        _motionPetIndex = null;
      }
    }
  }
  
  // --- TAP HANDLING ---
  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    final pos = info.eventPosition.global;
    _startTouchSound(pointerId, pos);
  }
  
  @override
  void onTapUp(int pointerId, TapUpInfo info) {
    _stopTouchSound(pointerId);
  }
  
  @override
  void onTapCancel(int pointerId) {
    _stopTouchSound(pointerId);
  }
  
  // --- DRAG HANDLING ---
  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    final pos = info.eventPosition.global;
    _startTouchSound(pointerId, pos);
  }
  
  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    final pos = info.eventPosition.global;
    _updateTouchSound(pointerId, pos);
  }
  
  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    _stopTouchSound(pointerId);
  }
  
  @override
  void onDragCancel(int pointerId) {
    _stopTouchSound(pointerId);
  }
  
  void _startTouchSound(int pointerId, Vector2 pos) {
    // Create new TonePlayer for this touch
    final player = TonePlayer();
    _touchPlayers[pointerId] = player;
    
    final frequency = _getFrequencyFromX(pos.x);
    final volume = _getVolumeFromY(pos.y);
    final petIndex = _getPetIndexFromX(pos.x);
    
    _touchPetIndex[pointerId] = petIndex;
    if (petIndex < _musicians.length) {
      _musicians[petIndex].startSinging(volume);
    }
    
    player.startTone(frequency, volume);
  }
  
  void _updateTouchSound(int pointerId, Vector2 pos) {
    final player = _touchPlayers[pointerId];
    if (player == null) return;
    
    final frequency = _getFrequencyFromX(pos.x);
    final volume = _getVolumeFromY(pos.y);
    final petIndex = _getPetIndexFromX(pos.x);
    
    // Update visual feedback
    final oldPetIndex = _touchPetIndex[pointerId];
    if (oldPetIndex != null && oldPetIndex != petIndex) {
      if (oldPetIndex < _musicians.length) {
        _musicians[oldPetIndex].stopSinging();
      }
    }
    _touchPetIndex[pointerId] = petIndex;
    if (petIndex < _musicians.length) {
      _musicians[petIndex].startSinging(volume);
    }
    
    // Update audio with smooth frequency change
    player.setFrequency(frequency, volume);
  }
  
  void _stopTouchSound(int pointerId) {
    final player = _touchPlayers.remove(pointerId);
    final petIndex = _touchPetIndex.remove(pointerId);
    
    if (petIndex != null && petIndex < _musicians.length) {
      _musicians[petIndex].stopSinging();
    }
    
    player?.stopTone();
    player?.dispose();
  }
  
  /// Clean up all audio and subscriptions. Call this when leaving the game.
  void cleanup() {
    // Stop all touch audio
    for (final player in _touchPlayers.values) {
      player.stopTone();
      player.dispose();
    }
    _touchPlayers.clear();
    
    // Stop motion audio
    _motionActive = false;
    _motionPlayer?.stopTone();
    _motionPlayer?.dispose();
    _motionPlayer = null;
    
    // Stop all pet visuals
    for (final musician in _musicians) {
      musician.stopSinging();
    }
    
    // Cancel telemetry subscription
    _telemetrySub?.cancel();
    _telemetrySub = null;
  }
  
  @override
  void onRemove() {
    cleanup();
    super.onRemove();
  }
}



/// Title display
class TitleDisplay extends PositionComponent {
  final OrchestraGame game;
  
  TitleDisplay({required this.game}) : super(position: Vector2(0, 20));
  
  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🎵 Pet Orchestra 🎵',
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: 'Monocraft',
          shadows: [Shadow(offset: Offset(2, 2), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((game.size.x - textPainter.width) / 2, 0));
  }
}

/// Exit button component
class ExitButton extends PositionComponent with TapCallbacks {
  final VoidCallback onTap;
  final OrchestraGame game;
  
  ExitButton({required this.onTap, required this.game}) : super(
    size: Vector2(80, 40),
    anchor: Anchor.center,
  );
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(60, 50);
  }
  
  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFE57373));
    canvas.drawRRect(rrect, Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'EXIT',
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Monocraft',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.x - textPainter.width) / 2, (size.y - textPainter.height) / 2),
    );
  }
  
  @override
  void onTapUp(TapUpEvent event) {
    onTap();
  }
}
