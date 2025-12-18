import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/flame.dart';
import 'package:flutter/animation.dart';

import 'pets/pet.dart';
import 'pets/body_type.dart';
import 'pets/pet_stats.dart';

/// BobTheBlob - A friendly blob pet with sprite-based rendering.
/// Uses a 2x2 sprite sheet with 4 frames based on wellbeing levels:
/// - Frame 0 (top-left): 75-100% wellbeing (happy)
/// - Frame 1 (top-right): 50-75% wellbeing (content)
/// - Frame 2 (bottom-left): 25-50% wellbeing (unhappy)
/// - Frame 3 (bottom-right): 0-25% wellbeing (critical)
/// 
/// Sprite sheet layout: 5px border, 5px gap between sprites.
/// Bob has a "ball" body type, meaning he can only wear hats and accessories.
class BobTheBlob extends Pet {
  /// The loaded sprite image
  Image? _spriteImage;
  
  /// Whether the sprite has been loaded
  bool _spriteLoaded = false;
  
  /// The current frame index based on wellbeing
  int _currentFrame = 0;
  
  /// Width of each sprite frame in the sheet (source size)
  double frameWidth = 25.0;
  
  /// Height of each sprite frame (source size)
  double frameHeight = 29.0;
  
  /// Offset for the source rect (used for dynamic sprite sizing)
  Vector2 _frameOffset = Vector2.zero();
  
  /// Last known game size for resize recalculation
  Vector2? _lastGameSize;
  
  /// Border padding around the sprite sheet
  static const double borderPadding = 4.0;
  
  /// Gap between sprites in the sheet
  static const double spriteGap = 5.0;
  
  /// Target display width as fraction of screen width
  static const double screenWidthFraction = 0.33; // 1/5 of screen
  
  BobTheBlob({
    PetStats? stats,
  }) : super(
    name: 'Bob',
    bodyType: BodyType.ball,
    stats: stats,
    // Initial size - will be updated in onGameResize
    // Initial size - will be updated in onGameResize
    size: Vector2(25.0 * 4, 116.0), // Use default 25x29 for init
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();
  }

  Future<void> _loadSprite() async {
    _spriteLoaded = false;
    
    // Check equipped items
    final headItem = stats.equippedClothing['head'];
    
    String spriteName;
    if (headItem == 'hat_spring') {
      spriteName = 'BobTheFruity.png';
      // Fruity sprite now matches standard dimensions: 25x29
      frameWidth = 25.0;
      frameHeight = 29.0;
      _frameOffset = Vector2.zero();
    } else if (headItem == 'hat_basic') {
      spriteName = 'BobTheBlob.png';
      frameWidth = 25.0;
      frameHeight = 29.0;
      _frameOffset = Vector2.zero();
    } else {
      spriteName = 'BobTheBlobHatless.png';
      frameWidth = 25.0;
      frameHeight = 29.0;
      _frameOffset = Vector2.zero();
    }
    
    _spriteImage = await Flame.images.load(spriteName);
    _spriteLoaded = true;
    
    // Recalculate component size/ratio
    if (_lastGameSize != null) {
      onGameResize(_lastGameSize!);
    }
  }

  @override
  void onGameResize(Vector2 gameSize) {
    _lastGameSize = gameSize;
    super.onGameResize(gameSize);
    
    // Calculate display size based on screen width (1/5 of screen)
    final targetWidth = gameSize.x * screenWidthFraction;
    final aspectRatio = frameHeight / frameWidth;
    final targetHeight = targetWidth * aspectRatio;
    
    size = Vector2(targetWidth, targetHeight);
  }

  /// Gets the source rectangle for a given frame index (0-3).
  /// Layout is 2x2 grid:
  ///   [0] [1]
  ///   [2] [3]
  Rect _getSourceRectForFrame(int frameIndex) {
    // Calculate row and column (2x2 grid)
    final col = frameIndex % 2;
    final row = frameIndex ~/ 2;
    
    // Calculate position with border and gap offsets
    final x = borderPadding + col * (frameWidth + spriteGap) + _frameOffset.x;
    final y = borderPadding + row * (frameHeight + spriteGap) + _frameOffset.y;
    
    return Rect.fromLTWH(x, y, frameWidth, frameHeight);
  }

  /// Determines which sprite frame to show based on wellbeing.
  /// Sprite sheet layout:
  ///   [0: serious] [1: smile]
  ///   [2: open mouth] [3: sad]
  int _getFrameForWellbeing(double wellbeing) {
    if (wellbeing >= 0.75) return 2; // Open mouth - happiest (75-100%)
    if (wellbeing >= 0.50) return 1; // Smile (50-75%)
    if (wellbeing >= 0.25) return 0; // Serious (25-50%)
    return 3; // Sad - critical (0-25%)
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update current frame based on wellbeing
    _currentFrame = _getFrameForWellbeing(stats.overallWellbeing);
  }

  @override
  Future<void> playEatAnimation() async {
    // Squash and stretch effect:
    // 1. Stretch vertically (scale Y > 1, scale X < 1)
    // 2. Return to normal
    await add(
      ScaleEffect.to(
        Vector2(0.8, 1.2),
        EffectController(
          duration: 0.15,
          reverseDuration: 0.15,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  Future<void> updateEquipment() async {
    // Reload sprite based on current equipment (switches between hatted/hatless)
    await _loadSprite();
    
    // Remove all existing clothing components
    children.whereType<SpriteComponent>().where((c) => c != this).forEach((c) => c.removeFromParent());
    
    final equipped = stats.equippedClothing;
    
    for (final entry in equipped.entries) {
      final slot = entry.key; // e.g. "head"
      final id = entry.value;
      
      // Skip items that are baked into the base sprite
      if (id == 'hat_basic' || id == 'hat_spring') continue;
      
      // Map ID to asset path
      String? assetPath;
      if (id.startsWith('hat_')) assetPath = 'clothing_$id.png';
      
      if (assetPath != null) {
        try {
          final image = await Flame.images.load(assetPath);
          final sprite = Sprite(image);
          add(
            SpriteComponent(
              sprite: sprite,
              size: size,
              position: Vector2.zero(), // Centered on pet
              anchor: Anchor.center,
            ),
          );
        } catch (e) {
          print('Error loading clothing sprite $assetPath: $e');
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_spriteLoaded || _spriteImage == null) {
      // Fallback: draw a simple placeholder while loading
      final paint = Paint()..color = const Color(0xFF306230);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        paint,
      );
      return;
    }
    
    // Get the source rectangle for the current wellbeing frame
    final srcRect = _getSourceRectForFrame(_currentFrame);
    final dstRect = Rect.fromLTWH(0, 0, size.x, size.y);
    
    // Draw the sprite
    canvas.drawImageRect(_spriteImage!, srcRect, dstRect, Paint());
  }
}

