import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../../services/bluetooth_service.dart';
import '../../../services/telemetry_data.dart';
import '../../pets/pet_stats.dart';
import 'pet_musician.dart';

/// Orchestra minigame where multiple pets sing at different pitches.
/// - Horizontal position determines pitch (left = low, right = high)
/// - Vertical position of touch determines volume (top = loud, bottom = quiet)
/// - Hold to sing, release to stop
/// - Multiple simultaneous touches for polyphony
class OrchestraGame extends FlameGame with MultiTouchDragDetector {
  final BluetoothService bluetoothService;
  final PetStats petStats;
  final VoidCallback onExit;
  final bool isDeviceConnected;
  
  /// Number of pets in the orchestra
  final int petCount;
  
  /// Musical notes (frequencies in Hz) - one octave of C major scale
  static const List<double> notes = [
    261.63, // C4
    293.66, // D4
    329.63, // E4
    349.23, // F4
    392.00, // G4
    440.00, // A4
    493.88, // B4
    523.25, // C5
  ];
  
  // Components
  final List<PetMusician> _musicians = [];
  
  // Touch tracking: pointerId -> pet index
  final Map<int, int> _activeTouches = {};
  
  // Motion control
  StreamSubscription<List<int>>? _telemetrySub;
  int? _motionPetIndex;
  Vector2 _calibrationOffset = Vector2.zero();
  bool _isCalibrated = false;
  
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
    
    // Create musicians
    for (int i = 0; i < petCount; i++) {
      final frequency = notes[i % notes.length];
      final xPos = petWidth * (i + 1);
      
      final musician = PetMusician(
        petStats: petStats,
        pitch: frequency,
        position: Vector2(xPos, baseY),
        size: Vector2(petWidth * 0.8, petHeight * 0.8),
      );
      
      _musicians.add(musician);
      add(musician);
    }
    
    // Add title
    add(TitleDisplay(game: this));
    
    // Add exit button
    add(ExitButton(onTap: onExit, game: this));
    
    // Subscribe to motion controls if connected
    if (isDeviceConnected) {
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
  
  void _onTelemetry(TelemetryData data) {
    if (!_isCalibrated) {
      // First reading sets calibration
      _calibrationOffset = Vector2(data.ax, data.ay);
      _isCalibrated = true;
      return;
    }
    
    // Map accelerometer to screen position
    // X axis: -1 to 1 -> left to right
    // Y axis: use for volume
    final relativeX = data.ax - _calibrationOffset.x;
    final relativeY = data.ay - _calibrationOffset.y;
    
    // Map to pet index (sensitivity of 0.5g per pet)
    final normalizedX = (relativeX / 0.5).clamp(-1.0, 1.0);
    final petIndex = ((normalizedX + 1) / 2 * (petCount - 1)).round().clamp(0, petCount - 1);
    
    // Map Y to volume (0.2 to 1.0)
    final normalizedY = (relativeY / 0.5).clamp(-1.0, 1.0);
    final volume = 0.6 + normalizedY * 0.4; // 0.2 to 1.0
    
    // Check if we should activate a new pet
    if (_motionPetIndex != petIndex) {
      // Stop old pet
      if (_motionPetIndex != null && _motionPetIndex! < _musicians.length) {
        _musicians[_motionPetIndex!].stopSinging();
      }
      _motionPetIndex = petIndex;
    }
    
    // Keep current pet singing with updated volume
    if (petIndex < _musicians.length) {
      _musicians[petIndex].startSinging(volume);
    }
  }
  
  /// Recalibrate motion controls to current orientation
  void recalibrate() {
    _isCalibrated = false;
    _motionPetIndex = null;
  }
  
  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    final petIndex = _getPetAtPosition(info.eventPosition.global);
    if (petIndex != null) {
      _activeTouches[pointerId] = petIndex;
      final volume = _getVolumeFromY(info.eventPosition.global.y);
      _musicians[petIndex].startSinging(volume);
    }
  }
  
  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    final currentPetIndex = _activeTouches[pointerId];
    if (currentPetIndex == null) return;
    
    final newPetIndex = _getPetAtPosition(info.eventPosition.global);
    final volume = _getVolumeFromY(info.eventPosition.global.y);
    
    if (newPetIndex != null && newPetIndex != currentPetIndex) {
      // Moved to a different pet
      _musicians[currentPetIndex].stopSinging();
      _activeTouches[pointerId] = newPetIndex;
      _musicians[newPetIndex].startSinging(volume);
    } else if (newPetIndex == currentPetIndex) {
      // Same pet, just update volume
      _musicians[currentPetIndex].updateVolume(volume);
    }
  }
  
  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    _stopTouchPet(pointerId);
  }
  
  @override
  void onDragCancel(int pointerId) {
    _stopTouchPet(pointerId);
  }
  
  void _stopTouchPet(int pointerId) {
    final petIndex = _activeTouches.remove(pointerId);
    if (petIndex != null && petIndex < _musicians.length) {
      _musicians[petIndex].stopSinging();
    }
  }
  
  int? _getPetAtPosition(Vector2 globalPos) {
    // Find which pet column the touch is in
    final petWidth = size.x / (petCount + 1);
    final index = (globalPos.x / petWidth - 0.5).round();
    if (index >= 0 && index < petCount) {
      return index;
    }
    return null;
  }
  
  double _getVolumeFromY(double y) {
    // Top of screen = loud (1.0), bottom = quiet (0.2)
    final normalized = 1.0 - (y / size.y).clamp(0.0, 1.0);
    return 0.2 + normalized * 0.8;
  }
  
  @override
  void onRemove() {
    _telemetrySub?.cancel();
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
    // Center horizontally
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
    // Position in top-left
    position = Vector2(60, 50);
  }
  
  @override
  void render(Canvas canvas) {
    // Button background
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFE57373));
    canvas.drawRRect(rrect, Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    
    // Text
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
