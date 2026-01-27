import 'dart:math';
import 'package:flutter/material.dart';

/// Temperature trend waveform painter for displaying GY906 temperature data.
/// 
/// Renders a scrolling line chart with a dark background and grid lines,
/// showing temperature readings over time.
class TemperatureWaveform extends StatelessWidget {
  /// List of temperature values to display.
  final List<double> data;
  
  /// Color of the waveform line.
  final Color lineColor;
  
  /// Background color.
  final Color backgroundColor;
  
  /// Grid line color.
  final Color gridColor;
  
  /// Line width for the waveform.
  final double lineWidth;
  
  const TemperatureWaveform({
    super.key,
    required this.data,
    this.lineColor = const Color(0xFFFF6600), // Orange for temperature
    this.backgroundColor = const Color(0xFF0A0A0A),
    this.gridColor = const Color(0xFF3A2A1A),
    this.lineWidth = 2.0,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gridColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _TemperatureWaveformPainter(
            data: data,
            lineColor: lineColor,
            gridColor: gridColor,
            lineWidth: lineWidth,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _TemperatureWaveformPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color gridColor;
  final double lineWidth;
  
  _TemperatureWaveformPainter({
    required this.data,
    required this.lineColor,
    required this.gridColor,
    required this.lineWidth,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    _drawGrid(canvas, size);
    
    // Draw waveform
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Calculate scaling
    final double xStep = size.width / max(data.length - 1, 1);
    
    // For temperature, use a fixed range around body temperature
    // This gives a more stable display than auto-scaling
    double minVal = 20.0;  // Room temperature minimum
    double maxVal = 45.0;  // Above fever maximum
    
    // Check if data is outside this range and expand if needed
    for (final v in data) {
      if (v < minVal) minVal = v - 2;
      if (v > maxVal) maxVal = v + 2;
    }
    
    final effectiveRange = maxVal - minVal;
    if (effectiveRange <= 0) return;
    
    // Draw the waveform path
    final path = Path();
    
    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final normalizedY = (data[i] - minVal) / effectiveRange;
      final y = size.height - (normalizedY * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw glow effect
    final glowPaint = Paint()
      ..color = lineColor.withAlpha(60)
      ..strokeWidth = lineWidth * 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawPath(path, glowPaint);
    
    // Draw temperature scale labels
    _drawScaleLabels(canvas, size, minVal, maxVal);
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    
    // Vertical grid lines (every ~40 pixels)
    final vSpacing = size.width / 10;
    for (double x = 0; x <= size.width; x += vSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    // Horizontal grid lines
    final hSpacing = size.height / 6;
    for (double y = 0; y <= size.height; y += hSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }
  
  void _drawScaleLabels(Canvas canvas, Size size, double minVal, double maxVal) {
    final textStyle = TextStyle(
      color: gridColor.withAlpha(200),
      fontSize: 10,
      fontFamily: 'monospace',
    );
    
    // Draw min and max labels on the right side
    final maxLabel = TextPainter(
      text: TextSpan(text: '${maxVal.toStringAsFixed(0)}°', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxLabel.paint(canvas, Offset(size.width - maxLabel.width - 4, 4));
    
    final minLabel = TextPainter(
      text: TextSpan(text: '${minVal.toStringAsFixed(0)}°', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    minLabel.paint(canvas, Offset(size.width - minLabel.width - 4, size.height - minLabel.height - 4));
  }
  
  @override
  bool shouldRepaint(covariant _TemperatureWaveformPainter oldDelegate) {
    return oldDelegate.data != data ||
           oldDelegate.lineColor != lineColor;
  }
}
