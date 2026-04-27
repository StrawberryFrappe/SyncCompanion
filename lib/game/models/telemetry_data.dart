import 'dart:math';
import 'dart:typed_data';

import '../../services/device/temperature_signal_processor.dart';

/// Decoded IMU telemetry data from the M5-IMU-Sensor device.
class TelemetryData {
  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;
  final int? rawIr;
  final int? rawRed;
  final int? rawTemp;

  const TelemetryData({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    this.rawIr,
    this.rawRed,
    this.rawTemp,
  });

  double get magnitude => sqrt(ax * ax + ay * ay + az * az);
  
  double? get temperatureCelsius => rawTemp != null 
      ? TemperatureSignalProcessor.rawToCelsius(rawTemp!) 
      : null;

  static TelemetryData? fromBytes(List<int> bytes) {
    if (bytes.length != 12 && bytes.length != 14 && bytes.length != 16) return null;
    
    try {
      final data = Uint8List.fromList(bytes);
      final byteData = ByteData.sublistView(data);
      
      final rawAx = byteData.getInt16(0, Endian.little);
      final rawAy = byteData.getInt16(2, Endian.little);
      final rawAz = byteData.getInt16(4, Endian.little);
      final rawGx = byteData.getInt16(6, Endian.little);
      final rawGy = byteData.getInt16(8, Endian.little);
      final rawGz = byteData.getInt16(10, Endian.little);
      
      int? rawIr;
      int? rawRed;
      int? rawTemp;
      
      if (bytes.length == 16) {
        rawIr = byteData.getUint16(12, Endian.little);
        rawRed = byteData.getUint16(14, Endian.little);
      } else if (bytes.length == 14) {
        rawTemp = byteData.getUint16(12, Endian.little);
      }
      
      return TelemetryData(
        ax: rawAx / 1000.0,
        ay: rawAy / 1000.0,
        az: rawAz / 1000.0,
        gx: rawGx / 10.0,
        gy: rawGy / 10.0,
        gz: rawGz / 10.0,
        rawIr: rawIr,
        rawRed: rawRed,
        rawTemp: rawTemp,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() {
    final bio = rawIr != null ? ' IR:$rawIr RED:$rawRed' : '';
    final temp = rawTemp != null ? ' TEMP:${temperatureCelsius?.toStringAsFixed(1)}°C' : '';
    return 'A:(${ax.toStringAsFixed(2)}, ${ay.toStringAsFixed(2)}, ${az.toStringAsFixed(2)}) '
           'G:(${gx.toStringAsFixed(1)}, ${gy.toStringAsFixed(1)}, ${gz.toStringAsFixed(1)})$bio$temp';
  }
}
