import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../services/device/device_service.dart';
import '../donut/donut.dart';
import 'motion_calibrator.dart';

/// Full-screen overlay shown before the SBR game starts (when device is
/// connected) to calibrate the user's wrist tilt range.
///
/// Tap-to-confirm calibration logic:
/// Phase 1 – Center: user holds wrist in a comfortable neutral pose and taps.
/// Phase 2 – Left: user tilts wrist max left and taps.
/// Phase 3 – Right: user tilts wrist max right and taps.
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

  double _latestRollAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _telemetrySub = widget.deviceService.telemetry$.listen(_onTelemetry);
    _calibrator.startCenterPhase();
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    super.dispose();
  }

  void _onTelemetry(TelemetryData data) {
    _latestRollAngle = MotionCalibrator.rollFromTelemetry(data);
  }

  void _handleTap() {
    setState(() {
      switch (_calibrator.state) {
        case CalibrationState.calibratingCenter:
          _calibrator.confirmCenter(_latestRollAngle);
          break;
        case CalibrationState.calibratingLeft:
          _calibrator.confirmLeft(_latestRollAngle);
          break;
        case CalibrationState.calibratingRight:
          _calibrator.confirmRight(_latestRollAngle);
          _finishCalibration();
          break;
        default:
          break;
      }
    });
  }

  void _finishCalibration() {
    _telemetrySub?.cancel();
    widget.onCalibrationComplete(_calibrator);
  }
  
  String _getInstruction(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    switch (_calibrator.state) {
      case CalibrationState.calibratingCenter:
        return loc.sbrCalibrationCenter;
      case CalibrationState.calibratingLeft:
        return loc.sbrCalibrationLeft;
      case CalibrationState.calibratingRight:
        return loc.sbrCalibrationRight;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Background: live 3-D donut (reacts to device telemetry)
          Positioned.fill(
            child: DonutGame(deviceService: widget.deviceService),
          ),

          // Semi-transparent overlay
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),

          // Instructions
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _getInstruction(context),
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
            ),
          ),
        ],
      ),
    );
  }
}
