import 'dart:math' as math;

import '../../../services/device/device_service.dart';

/// Calibration state machine states.
enum CalibrationState {
  idle,
  calibratingCenter,
  calibratingRange,
  done,
}

/// Processes IMU telemetry during a calibration phase to determine
/// the user's neutral wrist position and comfortable tilt range.
///
/// Usage:
///   1. Call [startCenterPhase] to begin collecting center samples.
///   2. Feed each [TelemetryData] packet via [addSample].
///   3. After the center timer expires, call [startRangePhase].
///   4. Continue feeding samples; the calibrator tracks min/max.
///   5. Call [finish] to lock in the calibration.
///   6. Use [mapAngleToScreenX] to convert live roll angles to bumper X.
class MotionCalibrator {
  CalibrationState state = CalibrationState.idle;

  // --- Center phase ---
  final List<double> _centerSamples = [];

  /// The neutral roll angle (degrees) when the user holds still.
  double centerAngle = 0.0;

  // --- Range phase ---
  double _minAngle = double.infinity;
  double _maxAngle = double.negativeInfinity;

  /// How far left (negative offset from center, in degrees) the user tilted.
  double leftExtent = 0.0;

  /// How far right (positive offset from center, in degrees) the user tilted.
  double rightExtent = 0.0;

  // --- Helpers ---

  /// Computes the roll angle in degrees from raw telemetry.
  /// Roll = rotation around the axis running along the forearm.
  static double rollFromTelemetry(TelemetryData data) {
    return math.atan2(
          -data.ax,
          math.sqrt(data.ay * data.ay + data.az * data.az),
        ) *
        180.0 /
        math.pi;
  }

  // --- State transitions ---

  void startCenterPhase() {
    state = CalibrationState.calibratingCenter;
    _centerSamples.clear();
  }

  void startRangePhase() {
    // Compute center from collected samples
    if (_centerSamples.isNotEmpty) {
      centerAngle =
          _centerSamples.reduce((a, b) => a + b) / _centerSamples.length;
    }

    // Initialise range tracking relative to center
    _minAngle = centerAngle;
    _maxAngle = centerAngle;

    state = CalibrationState.calibratingRange;
  }

  void finish() {
    leftExtent = (centerAngle - _minAngle).abs();
    rightExtent = (_maxAngle - centerAngle).abs();

    // Ensure a minimum range so division-by-zero can't happen
    if (leftExtent < 5.0) leftExtent = 5.0;
    if (rightExtent < 5.0) rightExtent = 5.0;

    state = CalibrationState.done;
  }

  // --- Sample ingestion ---

  void addSample(TelemetryData data) {
    final roll = rollFromTelemetry(data);

    switch (state) {
      case CalibrationState.calibratingCenter:
        _centerSamples.add(roll);
        break;
      case CalibrationState.calibratingRange:
        if (roll < _minAngle) _minAngle = roll;
        if (roll > _maxAngle) _maxAngle = roll;
        break;
      default:
        break;
    }
  }

  // --- Mapping ---

  /// Maps a live roll angle to a screen X coordinate in [0, screenWidth].
  ///
  /// The calibrated center maps to screen center.  The left/right extents
  /// map to 0 and screenWidth respectively, with clamping beyond the range.
  double mapAngleToScreenX(double rollAngle, double screenWidth) {
    final offset = rollAngle - centerAngle;
    double t; // -1..+1 normalised

    if (offset < 0) {
      t = -(offset.abs() / leftExtent).clamp(0.0, 1.0);
    } else {
      t = (offset / rightExtent).clamp(0.0, 1.0);
    }

    // t now in [-1, 1] → map to [0, screenWidth]
    return (t + 1.0) / 2.0 * screenWidth;
  }
}
