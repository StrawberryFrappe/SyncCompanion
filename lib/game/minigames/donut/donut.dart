import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';

import '../../../services/device/device_service.dart';


class DonutGame extends StatefulWidget {
  final DeviceService deviceService;

  const DonutGame({super.key, required this.deviceService});

  @override
  State<DonutGame> createState() => _DonutGameState();
}

class _DonutGameState extends State<DonutGame> {
  Object? _donut;
  Scene? _scene;
  StreamSubscription<TelemetryData>? _telemetrySub;
  
  // Camera Z for zoom
  double _cameraZ = 2.0; 

  // For pinch-to-zoom
  double _lastScale = 1.0;

  // For touch rotation
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  bool _usingTouch = false;

  @override
  void initState() {
    super.initState();
    _telemetrySub = widget.deviceService.telemetry$.listen(_onTelemetry);
    widget.deviceService.requestNativeStatus();
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    super.dispose();
  }

  void _onSceneCreated(Scene scene) {
    _scene = scene;
    scene.camera.position.setValues(0, 0, _cameraZ);
    scene.light.position.setValues(5, 10, 10);
    scene.light.setColor(Colors.white, 0.4, 0.8, 0.5); 
    _loadDonut();
  }

  void _loadDonut() {
    // Remove old donut if exists
    if (_donut != null) {
      _scene?.world.remove(_donut!);
    }
    
    // Load from asset
    final donut = Object(
      fileName: 'assets/models/donut.obj',
      isAsset: true,
      lighting: true,
    );
    
    _donut = donut;
    _scene?.world.add(_donut!);
    _scene?.update();
  }

  void _onTelemetry(TelemetryData data) {
    if (_donut == null || _usingTouch) return;
    final double pitch = math.atan2(data.ay, data.az) * 180 / math.pi;
    final double roll = math.atan2(-data.ax, math.sqrt(data.ay * data.ay + data.az * data.az)) * 180 / math.pi;
    
    _donut!.rotation.setValues(pitch, 0, roll);
    _donut!.updateTransform();
    _scene?.update();
  }

  void _updateCameraZ(double value) {
    setState(() => _cameraZ = value.clamp(1.0, 20.0));
    _scene?.camera.position.setValues(0, 0, _cameraZ);
    _scene?.update();
  }

  void _applyRotation() {
    if (_donut == null) return;
    _donut!.rotation.setValues(_rotationX, _rotationY, 0);
    _donut!.updateTransform();
    _scene?.update();
  }

  // --- Gesture handlers for zoom and rotation ---
  void _onScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
    _usingTouch = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Handle pinch-to-zoom (when 2+ fingers)
    if (details.scale != 1.0) {
      final double scaleDelta = details.scale / _lastScale;
      _lastScale = details.scale;
      final double newZ = _cameraZ / scaleDelta;
      _updateCameraZ(newZ);
    }
    
    // Handle rotation (single finger drag via focalPointDelta)
    final delta = details.focalPointDelta;
    _rotationY += delta.dx * 0.5;  // Horizontal drag = Y-axis rotation
    _rotationX -= delta.dy * 0.5;  // Vertical drag = X-axis rotation
    _applyRotation();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Keep using touch mode so telemetry doesn't override
    // User can shake device to re-enable telemetry control
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF222222), 
      appBar: AppBar(
        title: const Text('Spinning Donut', style: TextStyle(fontFamily: 'Monocraft')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Stack(
          children: [
            IgnorePointer(
              child: Cube(
                onSceneCreated: _onSceneCreated,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

