import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// BobTheBlob - A simple 32x32 colored square representing the virtual pet.
/// This is the initial placeholder that will evolve into a proper sprite later.
class BobTheBlob extends PositionComponent {
  BobTheBlob() : super(
    size: Vector2.all(32),
    anchor: Anchor.center,
  );

  // Dark GameBoy green for the blob
  static const Color blobColor = Color(0xFF306230);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      size.toRect(),
      Paint()..color = blobColor,
    );
  }
}
