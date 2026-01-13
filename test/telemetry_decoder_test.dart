import 'package:flutter_test/flutter_test.dart';
import 'package:sync_companion/services/device/device_service.dart';

void main() {
  group('TelemetryData', () {
    test('decodes valid 12-byte payload correctly', () {
      // Simulated payload:
      // ax = 100 (raw) → 1.0g   (bytes 0-1: 0x64, 0x00)
      // ay = -50 (raw) → -0.5g  (bytes 2-3: 0xCE, 0xFF = -50 signed)
      // az = 98 (raw) → 0.98g   (bytes 4-5: 0x62, 0x00)
      // gx = 250 (raw) → 25.0°/s (bytes 6-7: 0xFA, 0x00)
      // gy = -100 (raw) → -10.0°/s (bytes 8-9: 0x9C, 0xFF)
      // gz = 0 (raw) → 0.0°/s  (bytes 10-11: 0x00, 0x00)
      final bytes = [
        0x64, 0x00, // ax = 100
        0xCE, 0xFF, // ay = -50
        0x62, 0x00, // az = 98
        0xFA, 0x00, // gx = 250
        0x9C, 0xFF, // gy = -100
        0x00, 0x00, // gz = 0
      ];

      final data = TelemetryData.fromBytes(bytes);

      expect(data, isNotNull);
      expect(data!.ax, closeTo(1.0, 0.01));
      expect(data.ay, closeTo(-0.5, 0.01));
      expect(data.az, closeTo(0.98, 0.01));
      expect(data.gx, closeTo(25.0, 0.1));
      expect(data.gy, closeTo(-10.0, 0.1));
      expect(data.gz, closeTo(0.0, 0.1));
    });

    test('magnitude calculation is correct', () {
      // At rest: ax=0, ay=0, az=1g → magnitude = 1
      final bytes = [
        0x00, 0x00, // ax = 0
        0x00, 0x00, // ay = 0
        0x64, 0x00, // az = 100 → 1.0g
        0x00, 0x00, // gx = 0
        0x00, 0x00, // gy = 0
        0x00, 0x00, // gz = 0
      ];

      final data = TelemetryData.fromBytes(bytes);

      expect(data, isNotNull);
      expect(data!.magnitude, closeTo(1.0, 0.01));
    });

    test('returns null for invalid length', () {
      expect(TelemetryData.fromBytes([]), isNull);
      expect(TelemetryData.fromBytes([1, 2, 3]), isNull);
      expect(TelemetryData.fromBytes(List.filled(11, 0)), isNull);
      expect(TelemetryData.fromBytes(List.filled(13, 0)), isNull);
    });

    test('toString formats nicely', () {
      final bytes = [
        0x64, 0x00, // ax = 1.0
        0x00, 0x00, // ay = 0.0
        0x00, 0x00, // az = 0.0
        0x00, 0x00, // gx = 0.0
        0x00, 0x00, // gy = 0.0
        0x00, 0x00, // gz = 0.0
      ];

      final data = TelemetryData.fromBytes(bytes);
      expect(data.toString(), contains('A:(1.00'));
    });
  });
}
