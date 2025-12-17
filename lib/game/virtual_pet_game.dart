import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'bob_the_blob.dart';

/// VirtualPetGame - The main Flame game instance.
/// Renders a retro GameBoy-green background with the virtual pet centered.
class VirtualPetGame extends FlameGame {
  // Classic GameBoy screen green
  static const Color gameBoyGreen = Color(0xFF9BBC0F);

  @override
  Color backgroundColor() => gameBoyGreen;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Create and center BobTheBlob
    final bob = BobTheBlob()
      ..position = size / 2;
    
    add(bob);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    
    // Re-center BobTheBlob when screen resizes
    for (final component in children.whereType<BobTheBlob>()) {
      component.position = size / 2;
    }
  }
}
