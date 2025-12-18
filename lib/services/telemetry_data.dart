import 'dart:math';
import 'dart:typed_data';

/// Decoded IMU telemetry data from the M5-IMU-Sensor device.
/// 
/// The device sends 12 bytes: 6 × int16 little-endian values.
/// - Accelerometer (ax, ay, az): raw value ÷ 100 = g
/// - Gyroscope (gx, gy, gz): raw value ÷ 10 = deg/s
class TelemetryData {
  /// Accelerometer X-axis in g
  final double ax;
  /// Accelerometer Y-axis in g
  final double ay;
  /// Accelerometer Z-axis in g
  final double az;
  /// Gyroscope X-axis in deg/s
  final double gx;
  /// Gyroscope Y-axis in deg/s
  final double gy;
  /// Gyroscope Z-axis in deg/s
  final double gz;

  const TelemetryData({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  /// Magnitude of the acceleration vector.
  /// Useful for motion detection (e.g., jump threshold in games).
  /// At rest, this should be ~1.0g (gravity).
  double get magnitude => sqrt(ax * ax + ay * ay + az * az);

  /// Factory to decode 12-byte IMU payload.
  /// Returns null if bytes are invalid.
  static TelemetryData? fromBytes(List<int> bytes) {
    if (bytes.length != 12) return null;
    
    try {
      final data = Uint8List.fromList(bytes);
      final byteData = ByteData.sublistView(data);
      
      // Read 6 × int16 little-endian
      final rawAx = byteData.getInt16(0, Endian.little);
      final rawAy = byteData.getInt16(2, Endian.little);
      final rawAz = byteData.getInt16(4, Endian.little);
      final rawGx = byteData.getInt16(6, Endian.little);
      final rawGy = byteData.getInt16(8, Endian.little);
      final rawGz = byteData.getInt16(10, Endian.little);
      
      return TelemetryData(
        ax: rawAx / 100.0,
        ay: rawAy / 100.0,
        az: rawAz / 100.0,
        gx: rawGx / 10.0,
        gy: rawGy / 10.0,
        gz: rawGz / 10.0,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 
      'A:(${ax.toStringAsFixed(2)}, ${ay.toStringAsFixed(2)}, ${az.toStringAsFixed(2)}) '
      'G:(${gx.toStringAsFixed(1)}, ${gy.toStringAsFixed(1)}, ${gz.toStringAsFixed(1)})';
}
