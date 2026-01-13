import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../../../screens/widgets/menus/food_menu.dart';

/// Food sprite for Flappy Bird game (fallback when device not connected).
/// Uses a random food asset for the silly penalty effect.
class FlappyFood extends PositionComponent {
  /// Current vertical velocity
  double velocity = 0;
  
  Image? _spriteImage;
  bool _loaded = false;

  FlappyFood() : super(
    size: Vector2(50, 50),
    anchor: Anchor.center,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();
  }
  
  Future<void> _loadSprite() async {
    // Pick a random food item
    final random = Random();
    final items = FoodMenuData.items;
    final food = items[random.nextInt(items.length)];
    
    // Load the food asset
    // FoodMenuItem assetPath is 'assets/images/food_apple.png'
    // Flame.images.load() expects just 'food_apple.png' (it auto-prefixes 'images/')
    final assetPath = food.assetPath.replaceFirst('assets/images/', '');
    try {
      _spriteImage = await Flame.images.load(assetPath);
      _loaded = true;
    } catch (e) {
      // Will use fallback rendering
      print('FlappyFood: failed to load $assetPath: $e');
    }
  }

  void flap(double flapVelocity) {
    velocity = flapVelocity;
  }

  @override
  void render(Canvas canvas) {
    if (!_loaded || _spriteImage == null) {
      // Placeholder: colored circle
      canvas.drawOval(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFFFF6B6B),
      );
      return;
    }
    
    final srcRect = Rect.fromLTWH(
      0, 0,
      _spriteImage!.width.toDouble(),
      _spriteImage!.height.toDouble(),
    );
    final dstRect = Rect.fromLTWH(0, 0, size.x, size.y);
    
    canvas.drawImageRect(_spriteImage!, srcRect, dstRect, Paint());
  }
}
