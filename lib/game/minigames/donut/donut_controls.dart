import 'package:flutter/material.dart';

/// Debug controls panel for tuning donut camera.
/// This is a temporary UI for development and can be removed later.
class DonutDebugControls extends StatelessWidget {
  final double cameraZ;
  final ValueChanged<double> onCameraZChanged;

  const DonutDebugControls({
    super.key,
    required this.cameraZ,
    required this.onCameraZChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Text('Cam Z:', style: TextStyle(color: Colors.white, fontSize: 10)),
          Expanded(
            child: Slider(
              value: cameraZ,
              min: 1,
              max: 20,
              onChanged: onCameraZChanged,
            ),
          ),
          Text('${cameraZ.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }
}

