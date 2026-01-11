import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A glowing cursor driven by motion controls.
class MotionCursor extends PositionComponent {
  final double radius;
  final Color color;
  
  // Visual pulsing
  double _pulsePhase = 0;
  
  MotionCursor({
    Vector2? position,
    this.radius = 15.0,
    this.color = const Color(0xFF64FFDA), // Cyan accent
  }) : super(
    position: position ?? Vector2.zero(),
    size: Vector2.all(radius * 2),
    anchor: Anchor.center,
    priority: 100, // Always on top
  );

  @override
  void update(double dt) {
    super.update(dt);
    _pulsePhase += dt * 5;
  }

  @override
  void render(Canvas canvas) {
    // Outer glow
    final pulseScale = 1.0 + 0.2 * (0.5 + 0.5 * (math.sin(_pulsePhase)));
    
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius * pulseScale * 1.5,
      glowPaint,
    );
    
    // Core
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius,
      corePaint,
    );
    
    // Center bright spot
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius * 0.4,
      centerPaint,
    );
  }
}
