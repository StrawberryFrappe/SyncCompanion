import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../../pets/pet_stats.dart';
import 'tone_player.dart';

/// A pet sprite that can "sing" when activated.
/// Each PetMusician has a fixed pitch (based on X position) and
/// variable volume (based on Y input).
class PetMusician extends PositionComponent {
  final PetStats petStats;
  final double pitch; // Hz
  final TonePlayer _tonePlayer = TonePlayer();
  
  bool isSinging = false;
  double _currentVolume = 0.5;
  
  Image? _spriteImage;
  bool _loaded = false;
  
  // Visual feedback
  double _scalePhase = 0.0;
  
  PetMusician({
    required this.petStats,
    required this.pitch,
    Vector2? position,
    Vector2? size,
  }) : super(
    position: position ?? Vector2.zero(),
    size: size ?? Vector2(50, 58),
    anchor: Anchor.center,
  );
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();
  }
  
  Future<void> _loadSprite() async {
    // Same sprite logic as FlappyPet
    final headItem = petStats.equippedClothing['head'];
    
    String spriteName;
    if (headItem == 'hat_spring') {
      spriteName = 'BobTheFruity.png';
    } else if (headItem == 'hat_basic') {
      spriteName = 'BobTheBlob.png';
    } else {
      spriteName = 'BobTheBlobHatless.png';
    }
    
    _spriteImage = await Flame.images.load(spriteName);
    _loaded = true;
  }
  
  /// Start singing at the given volume (0.0 - 1.0)
  Future<void> startSinging(double volume) async {
    if (isSinging) {
      // Just update volume
      _currentVolume = volume;
      await _tonePlayer.setVolume(volume);
      return;
    }
    
    isSinging = true;
    _currentVolume = volume;
    await _tonePlayer.startTone(pitch, volume);
  }
  
  /// Update volume while singing
  Future<void> updateVolume(double volume) async {
    _currentVolume = volume;
    if (isSinging) {
      await _tonePlayer.setVolume(volume);
    }
  }
  
  /// Stop singing
  Future<void> stopSinging() async {
    if (!isSinging) return;
    isSinging = false;
    await _tonePlayer.stopTone();
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Animate scale when singing
    if (isSinging) {
      _scalePhase += dt * 10; // Speed of wobble
    } else {
      _scalePhase = 0;
    }
  }
  
  @override
  void render(Canvas canvas) {
    if (!_loaded || _spriteImage == null) {
      // Placeholder
      canvas.drawOval(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF306230),
      );
      return;
    }
    
    // Apply scale animation when singing
    double scaleX = 1.0;
    double scaleY = 1.0;
    if (isSinging) {
      final wobble = 0.05 * _currentVolume;
      scaleX = 1.0 + wobble * (1 + (0.5 * (1 + (_scalePhase).remainder(1.0))));
      scaleY = 1.0 - wobble * 0.5 * (1 + (_scalePhase).remainder(1.0));
    }
    
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-size.x / 2, -size.y / 2);
    
    // Draw frame 1 (smiling) from 2x2 grid
    const borderPadding = 4.0;
    const spriteGap = 5.0;
    const frameWidth = 25.0;
    const frameHeight = 29.0;
    
    // Frame 1 is top-right (col=1, row=0)
    final srcRect = Rect.fromLTWH(
      borderPadding + 1 * (frameWidth + spriteGap),
      borderPadding + 0 * (frameHeight + spriteGap),
      frameWidth,
      frameHeight,
    );
    final dstRect = Rect.fromLTWH(0, 0, size.x, size.y);
    
    canvas.drawImageRect(_spriteImage!, srcRect, dstRect, Paint());
    canvas.restore();
  }
  
  @override
  void onRemove() {
    _tonePlayer.dispose();
    super.onRemove();
  }
}
