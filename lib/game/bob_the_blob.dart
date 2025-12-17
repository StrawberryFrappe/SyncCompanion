import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'pets/pet.dart';
import 'pets/body_type.dart';
import 'pets/pet_stats.dart';

/// BobTheBlob - A friendly ovoid blob pet.
/// Bob has a "ball" body type, meaning he can only wear hats and accessories.
class BobTheBlob extends Pet {
  BobTheBlob({
    PetStats? stats,
  }) : super(
    name: 'Bob',
    bodyType: BodyType.ball,
    stats: stats,
    size: Vector2(48, 32), // Horizontally stretched ovoid
  );

  // Dark GameBoy green for the blob
  static const Color blobColor = Color(0xFF306230);
  
  // Slightly lighter outline
  static const Color outlineColor = Color(0xFF0F380F);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = blobColor;
    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw as horizontally-stretched ellipse (ovoid shape)
    final rect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2),
      width: size.x,
      height: size.y,
    );
    
    // Fill
    canvas.drawOval(rect, paint);
    
    // Outline
    canvas.drawOval(rect, outlinePaint);
    
    // Simple eyes (two small circles)
    final eyePaint = Paint()..color = outlineColor;
    final eyeRadius = 3.0;
    final eyeY = size.y / 2 - 2;
    
    // Left eye
    canvas.drawCircle(
      Offset(size.x / 2 - 8, eyeY),
      eyeRadius,
      eyePaint,
    );
    
    // Right eye
    canvas.drawCircle(
      Offset(size.x / 2 + 8, eyeY),
      eyeRadius,
      eyePaint,
    );
  }
}
