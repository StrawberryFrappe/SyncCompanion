import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/device/device_service.dart';
import '../donut/donut.dart';
import 'motion_calibrator.dart';

/// Full-screen overlay shown before the SBR game starts (when device is
/// connected) to calibrate the user's wrist tilt range.
///
/// Phase 1 – Center (~2 s): user holds wrist in a comfortable neutral pose.
/// Phase 2 – Range  (~3 s): user tilts wrist left and right comfortably.
///
/// The 3-D Donut is rendered behind the instructions so the user gets
/// immediate visual feedback that their movement is being tracked.
class CalibrationOverlay extends StatefulWidget {
  final DeviceService deviceService;
  final ValueChanged<MotionCalibrator> onCalibrationComplete;

  const CalibrationOverlay({
    super.key,
    required this.deviceService,
    required this.onCalibrationComplete,
  });

  @override
  State<CalibrationOverlay> createState() => _CalibrationOverlayState();
}

class _CalibrationOverlayState extends State<CalibrationOverlay> {
  final MotionCalibrator _calibrator = MotionCalibrator();
  StreamSubscription<TelemetryData>? _telemetrySub;

  // Countdown display
  int _secondsRemaining = 2;
  Timer? _countdownTimer;
  String _instruction = 'Hold your wrist still\nin a comfortable position';

  @override
  void initState() {
    super.initState();
    _telemetrySub = widget.deviceService.telemetry$.listen(_onTelemetry);
    _startCenterPhase();
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onTelemetry(TelemetryData data) {
    _calibrator.addSample(data);
  }

  // --- Phase 1: Center ---
  void _startCenterPhase() {
    _calibrator.startCenterPhase();
    _secondsRemaining = 2;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _startRangePhase();
      }
    });
  }

  // --- Phase 2: Range ---
  void _startRangePhase() {
    _calibrator.startRangePhase();
    setState(() {
      _instruction = 'Now tilt your wrist\nleft and right';
      _secondsRemaining = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _finishCalibration();
      }
    });
  }

  void _finishCalibration() {
    _calibrator.finish();
    _telemetrySub?.cancel();
    widget.onCalibrationComplete(_calibrator);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background: live 3-D donut (reacts to device telemetry)
        Positioned.fill(
          child: DonutGame(deviceService: widget.deviceService),
        ),

        // Semi-transparent overlay
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.45)),
        ),

        // Instructions + countdown
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(offset: Offset(2, 2), blurRadius: 6, color: Colors.black87),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$_secondsRemaining',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(offset: Offset(2, 2), blurRadius: 8, color: Colors.black87),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
