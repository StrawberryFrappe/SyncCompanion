import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../../services/device_service.dart';
import '../../../services/telemetry_data.dart';
import '../../pets/pet_stats.dart';
import 'cursor.dart';
import 'pet_musician.dart';
import 'tone_player.dart';

/// Orchestra minigame where pets sing at different pitches based on touch position.
/// - Horizontal position determines pitch (smooth glide, not discrete notes)
/// - Vertical position determines volume (top = loud, bottom = quiet)
/// - Hold to sing, release to stop
/// - Multiple simultaneous touches for polyphony
/// Orchestra minigame where pets form a choir and are conducted by motion.
/// - Tilt X: Pitch (Low -> High)
/// - Tilt Y: Volume (Quiet -> Loud)
/// - Visuals: Cursor follows tilt, pets animate based on their vocal range.
class OrchestraGame extends FlameGame with MultiTouchDragDetector, MultiTouchTapDetector {
  final DeviceService deviceService;
  final PetStats petStats;
  final VoidCallback onExit;
  final bool isDeviceConnected;
  
  // Musicians
  final List<PetMusician> _musicians = [];
  
  // Audio
  final TonePlayer _mainPlayer = TonePlayer();
  
  // Controls
  late MotionCursor _cursor;
  StreamSubscription<TelemetryData>? _telemetrySub;
  
  // State
  double _currentPitch = 0.0; // 0.0 to 1.0
  double _currentVolume = 0.0; // 0.0 to 1.0
  bool _isPlaying = false;
  
  // Motion Calibration/Smoothing
  Vector2 _calibrationOffset = Vector2.zero();
  bool _isCalibrated = false;
  Vector2 _smoothedMotion = Vector2.zero(); // Matches tilt range (-1 to 1 approx)
  static const double smoothingFactor = 0.15; // Smooth movement
  
  // Musical Range (Expanded ~4.5 octaves)
  static const double minFrequency = 65.41; // C2 (Deep Bass)
  static const double maxFrequency = 1567.98; // G6 (High Soprano)
  
  OrchestraGame({
    required this.deviceService,
    required this.petStats,
    required this.onExit,
    this.isDeviceConnected = false,
  });
  
  @override
  Color backgroundColor() => const Color(0xFF2D1B4E); // Deep purple stage
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 1. Setup Stage & Musicians (Chorus Layout)
    _setupChorus();
    
    // 2. Add Cursor
    _cursor = MotionCursor(position: size / 2);
    add(_cursor);
    
    // 3. Add UI
    add(TitleDisplay(game: this));
    add(ExitButton(onTap: _handleExit, game: this));
    
    // 4. Input Setup
    if (isDeviceConnected) {
      _telemetrySub = deviceService.telemetry$.listen(
        _onTelemetry,
        onError: (e) => print('[Orchestra] Telemetry error: $e'),
      );
      deviceService.requestNativeStatus();
    }
  }
  
  void _setupChorus() {
    // Layout: 3 Rows (Bleachers)
    // Back Row (Bass): High up on screen, smaller, low pitch range
    // Mid Row (Tenor/Alto): Middle, medium size, mid pitch range
    // Front Row (Soprano): Bottom, large, high pitch range
    
    // Row 1: Bass (Top, Back)
    _createRow(
      count: 6,
      yPos: size.y * 0.45,
      scale: 0.6,
      minPitch: 0.0,
      maxPitch: 0.4,
    );
    
    // Row 2: Mids (Middle)
    _createRow(
      count: 5,
      yPos: size.y * 0.65,
      scale: 0.8,
      minPitch: 0.3,
      maxPitch: 0.7,
    );
    
    // Row 3: Soprano (Front, Bottom)
    _createRow(
      count: 4,
      yPos: size.y * 0.85,
      scale: 1.0,
      minPitch: 0.6,
      maxPitch: 1.0,
    );
    
    // Add all to game
    addAll(_musicians);
  }
  
  void _createRow({
    required int count, 
    required double yPos, 
    required double scale,
    required double minPitch,
    required double maxPitch,
  }) {
    final rowWidth = size.x * 0.8;
    final spacing = rowWidth / (count + 1);
    final startX = (size.x - rowWidth) / 2 + spacing;
    
    for (int i = 0; i < count; i++) {
        // Assign a specific "center pitch" for this pet within the row's range
        final rowRange = maxPitch - minPitch;
        final petPitchCenter = minPitch + (rowRange * (i / (count - 1)));
        
        // Define their comfortable range around that center
        final petMin = (petPitchCenter - 0.15).clamp(0.0, 1.0);
        final petMax = (petPitchCenter + 0.15).clamp(0.0, 1.0);
        
        final musician = PetMusician(
            petStats: petStats,
            pitch: petPitchCenter,
            minPitchRange: petMin,
            maxPitchRange: petMax,
            position: Vector2(startX + (spacing * i), yPos),
            size: Vector2(100, 116) * scale, // Base size scaled
        );
        _musicians.add(musician);
    }
  }

  void _handleExit() {
    cleanup();
    onExit();
  }
  
  // --- AUDIO LOGIC ---
  
  double _getFrequencyFromPitch(double pitch) {
    // Exponential interpolation
    final logMin = math.log(minFrequency);
    final logMax = math.log(maxFrequency);
    return math.exp(logMin + pitch * (logMax - logMin));
  }
  
  void _updateAudio() {
    if (_currentVolume < 0.05) {
      if (_isPlaying) {
        _mainPlayer.stopTone();
        _isPlaying = false;
      }
    } else {
      final freq = _getFrequencyFromPitch(_currentPitch);
      if (!_isPlaying) {
        _mainPlayer.startTone(freq, _currentVolume);
        _isPlaying = true;
      } else {
        _mainPlayer.setFrequency(freq, _currentVolume);
      }
    }
    
    // Update Musician States
    for (final musician in _musicians) {
      musician.updateSingingState(_currentPitch, _currentVolume);
    }
  }

  // --- INPUT HANDLING ---

  void _onTelemetry(TelemetryData data) {
    if (!_isCalibrated) {
      _calibrationOffset = Vector2(data.ax, data.ay);
      _smoothedMotion = Vector2.zero();
      _isCalibrated = true;
      return;
    }
    
    // Raw relative tilt
    final rawX = data.ax - _calibrationOffset.x; // Left/Right tilt
    final rawY = data.ay - _calibrationOffset.y; // Forward/Back tilt
    
    // Smooth it
    _smoothedMotion.x = _smoothedMotion.x + smoothingFactor * (rawX - _smoothedMotion.x);
    _smoothedMotion.y = _smoothedMotion.y + smoothingFactor * (rawY - _smoothedMotion.y);
    
    // Map to Game State
    // Tilt X -> Pitch
    // Range approx -0.5 to 0.5 -> 0.0 to 1.0
    _currentPitch = ((_smoothedMotion.x / 0.6) + 0.5).clamp(0.0, 1.0);
    
    // Tilt Y -> Volume
    // Range approx -0.5 to 0.5 -> 0.0 to 1.0
    // Tilting BACK (positive Y usually) should be Higher Volume? Or Forward?
    // Let's say tilting AWAY (top of phone goes down, Y decreases?) is volume up.
    // Actually, usually Y is gravity. Flat = 0.
    // Let's just map standard -0.5 to 0.5.
    // Let's make: Tilt Right (X > 0) = High Pitch.
    // Tilt Up/Back (Y < 0) = High Volume.
    
    // Mapping: 
    // Y < 0 (Tilted away) -> Volume 1.0
    // Y > 0 (Tilted towards) -> Volume 0.0
    _currentVolume = ((_smoothedMotion.y / -0.8) + 0.5).clamp(0.0, 1.0);
    
    // Update Cursor Position for feedback
    final screenX = _currentPitch * size.x;
    final screenY = (1.0 - _currentVolume) * size.y; // High volume = Top of screen
    _cursor.position = Vector2(screenX, screenY);
  }

  // Fallback Touch Controls
  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    // Only use touch if NO motion input detected recently? 
    // Or just override. Let's override for debugging.
    final pos = info.eventPosition.global;
    _currentPitch = (pos.x / size.x).clamp(0.0, 1.0);
    _currentVolume = 1.0 - (pos.y / size.y).clamp(0.0, 1.0);
    
    _cursor.position = pos;
  }
  
  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    final pos = info.eventPosition.global;
    _currentPitch = (pos.x / size.x).clamp(0.0, 1.0);
    _currentVolume = 1.0 - (pos.y / size.y).clamp(0.0, 1.0);
    _cursor.position = pos;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    _updateAudio();
  }

  /// Clean up all audio and subscriptions. Call this when leaving the game.
  void cleanup() {
    _mainPlayer.stopTone();
    _mainPlayer.dispose();
    
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
