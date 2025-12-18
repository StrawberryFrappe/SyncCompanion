import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../../pets/pet_stats.dart';

/// Pet sprite for Flappy Bird game. Uses the same sprite and clothing as main pet.
class FlappyPet extends PositionComponent {
  final PetStats petStats;
  
  /// Current vertical velocity
  double velocity = 0;
  
  Image? _spriteImage;
  bool _loaded = false;

  FlappyPet({required this.petStats}) : super(
    size: Vector2(50, 58), // Scaled from 25x29
    anchor: Anchor.center,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();
  }
  
  Future<void> _loadSprite() async {
    // Determine sprite based on equipped clothing (same logic as BobTheBlob)
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

  void flap(double flapVelocity) {
    velocity = flapVelocity;
  }

  @override
  void render(Canvas canvas) {
    if (!_loaded || _spriteImage == null) {
      // Placeholder while loading
      canvas.drawOval(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF306230),
      );
      return;
    }
    
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
  }
}
