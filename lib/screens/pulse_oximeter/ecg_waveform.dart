import 'dart:math';
import 'package:flutter/material.dart';

/// ECG-style waveform painter for displaying bio-sensor data.
/// 
/// Renders a scrolling line chart with a dark background and grid lines,
/// similar to a medical ECG monitor.
class EcgWaveform extends StatelessWidget {
  /// List of filtered signal values to display.
  final List<double> data;
  
  /// Color of the waveform line.
  final Color lineColor;
  
  /// Background color.
  final Color backgroundColor;
  
  /// Grid line color.
  final Color gridColor;
  
  /// Line width for the waveform.
  final double lineWidth;
  
  const EcgWaveform({
    super.key,
    required this.data,
    this.lineColor = const Color(0xFF00FF00), // Classic ECG green
    this.backgroundColor = const Color(0xFF0A0A0A),
    this.gridColor = const Color(0xFF1A3A1A),
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
          painter: _EcgWaveformPainter(
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

class _EcgWaveformPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color gridColor;
  final double lineWidth;
  
  _EcgWaveformPainter({
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
    
    // Find min/max for vertical scaling
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    for (final v in data) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }
    
    // Add some padding to the range
    final range = maxVal - minVal;
    final padding = range * 0.1;
    minVal -= padding;
    maxVal += padding;
    
    // Avoid division by zero
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
  
  @override
  bool shouldRepaint(covariant _EcgWaveformPainter oldDelegate) {
    return oldDelegate.data != data ||
           oldDelegate.lineColor != lineColor;
  }
}

/// Widget that displays no signal / sensor disconnected state.
class NoSignalIndicator extends StatelessWidget {
  const NoSignalIndicator({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A1A1A), width: 2),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sensors_off,
              size: 48,
              color: Color(0xFFFF4444),
            ),
            SizedBox(height: 8),
            Text(
              'SENSOR DISCONNECTED',
              style: TextStyle(
                color: Color(0xFFFF4444),
                fontSize: 14,
                fontFamily: 'Monocraft',
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Place your finger on the sensor',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget that displays when sensor is initializing.
class InitializingIndicator extends StatelessWidget {
  const InitializingIndicator({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A3A3A), width: 2),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF00AAAA),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'INITIALIZING SENSOR',
              style: TextStyle(
                color: Color(0xFF00AAAA),
                fontSize: 14,
                fontFamily: 'Monocraft',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
