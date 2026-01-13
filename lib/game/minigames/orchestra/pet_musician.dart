import 'dart:ui';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../../pets/pet_stats.dart';

/// A pet sprite that provides visual feedback when "singing".
/// Audio is now managed by OrchestraGame directly for smooth pitch glide.
class PetMusician extends PositionComponent {
  final PetStats petStats;
  // Vocal range for this pet (0.0 to 1.0 normalized frequency)
  final double minPitchRange;
  final double maxPitchRange;

  /// Assigned base pitch/position in choir (0.0 to 1.0)
  final double pitch;

  // State
  bool isSinging = false;
  double _currentVolume = 0.0;
  
  // Visuals
  Image? _spriteImage;
  bool _loaded = false;
  double _scalePhase = 0.0; // For wobble animation

  PetMusician({
    required this.petStats,
    required this.pitch, // Assigned base pitch/position in choir
    this.minPitchRange = 0.0,
    this.maxPitchRange = 1.0,
    Vector2? position,
    Vector2? size,
  }) : super(
    position: position ?? Vector2.zero(),
    size: size ?? Vector2(50, 58),
    anchor: Anchor.bottomCenter, // Anchor at bottom so they stretch up
  );
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();
  }
  
  Future<void> _loadSprite() async {
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
  
  /// Update singing state based on global frequency and volume
  /// [normalizedFrequency] 0.0 (Low) to 1.0 (High)
  /// [volume] 0.0 (Silence) to 1.0 (Max)
  void updateSingingState(double normalizedFrequency, double volume) {
    // Check if the note is within this pet's range (with some overlap)
    // Adding a small fade/falloff would be nice, but hard cutoff is fine for now
    if (volume > 0.05 && 
        normalizedFrequency >= minPitchRange - 0.1 && 
        normalizedFrequency <= maxPitchRange + 0.1) {
      
      isSinging = true;
      _currentVolume = volume;
      
      // Calculate how "close" we are to the center of this pet's range
      // or strictly map stretch to the global frequency
      // Let's map stretch to the global frequency so high notes = tall pets everywhere
      _scalePhase = normalizedFrequency; // Reuse _scalePhase to store target stretch
      
    } else {
      isSinging = false;
      _currentVolume = 0.0;
    }
  }

  /// Force stop singing
  void stopSinging() {
    isSinging = false;
    _currentVolume = 0.0;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    // Smooth transition for volume could go here if needed
  }
  
  @override
  void render(Canvas canvas) {
    if (!_loaded || _spriteImage == null) {
      canvas.drawOval(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF306230),
      );
      return;
    }
    
    // Calculate Squash and Stretch
    double targetScaleX = 1.0;
    double targetScaleY = 1.0;
    
    if (isSinging) {
      // High pitch = Stretch Up (ScaleY > 1, ScaleX < 1)
      // Low pitch = Squash Down (ScaleY < 1, ScaleX > 1)
      
      // _scalePhase holds the normalized frequency (0.0 to 1.0)
      // Map 0.0 -> Squash (0.8 Y)
      // Map 1.0 -> Stretch (1.4 Y)
      final stretchFactor = 0.8 + (_scalePhase * 0.6);
      
      // Maintain rough area/volume conservation: X * Y ~= 1
      targetScaleY = stretchFactor;
      targetScaleX = 1.0 / math.sqrt(stretchFactor);
      
      // Add volume wobble
      final wobble = 0.1 * _currentVolume * math.sin(DateTime.now().millisecondsSinceEpoch / 50);
      targetScaleX += wobble;
      targetScaleY += wobble;
      
      // Apply volume scale (mouth opening effectively)
      final volScale = 1.0 + (_currentVolume * 0.2);
      targetScaleX *= volScale;
      targetScaleY *= volScale;
    }
    
    // We anchor at bottomCenter, so scaling happens upwards naturally from the anchor point?
    // Flame components scale from the anchor. Since custom render, we must handle manually
    // or rely on the component's scale property.
    // Let's use canvas scaling relative to the bottom center of the sprite rect.
    
    canvas.save();
    
    // Pivot at bottom center of the size box
    canvas.translate(size.x / 2, size.y); 
    canvas.scale(targetScaleX, targetScaleY);
    canvas.translate(-size.x / 2, -size.y);
    
    // Draw frame 1 (smiling) from 2x2 grid
    // TODO: Switch to "Mouth Open" frame if we had one.
    // For now we just use the standard smile.
    
    const borderPadding = 4.0;
    const spriteGap = 5.0;
    const frameWidth = 25.0;
    const frameHeight = 29.0;
    
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
}
