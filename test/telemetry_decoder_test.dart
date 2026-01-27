import 'package:flutter_test/flutter_test.dart';
import 'package:Therapets/services/device/device_service.dart';

void main() {
  group('TelemetryData', () {
    test('decodes valid 12-byte IMU-only payload correctly', () {
      // Simulated payload (12-byte IMU only):
      // ax = 1000 (raw) → 1.0g   (bytes 0-1: 0xE8, 0x03 = 1000)
      // ay = -500 (raw) → -0.5g  (bytes 2-3: 0x0C, 0xFE = -500 signed)
      // az = 980 (raw) → 0.98g   (bytes 4-5: 0xD4, 0x03)
      // gx = 250 (raw) → 25.0°/s (bytes 6-7: 0xFA, 0x00)
      // gy = -100 (raw) → -10.0°/s (bytes 8-9: 0x9C, 0xFF)
      // gz = 0 (raw) → 0.0°/s  (bytes 10-11: 0x00, 0x00)
      final bytes = [
        0xE8, 0x03, // ax = 1000
        0x0C, 0xFE, // ay = -500
        0xD4, 0x03, // az = 980
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
      expect(data.rawIr, isNull);
      expect(data.rawRed, isNull);
      expect(data.rawTemp, isNull);
    });
    
    test('decodes valid 14-byte GY906 temperature payload correctly', () {
      // 14-byte payload: IMU + GY906 temperature sensor
      // Temperature raw value of 18661 → (18661 * 0.02) - 273.15 = 100.07°C (boiling point test)
      // Human body temperature ~37°C: raw = (37 + 273.15) / 0.02 = 15507.5 ≈ 15508
      final bytes = [
        0xE8, 0x03, // ax = 1000 → 1.0g
        0x00, 0x00, // ay = 0
        0x00, 0x00, // az = 0
        0x00, 0x00, // gx = 0
        0x00, 0x00, // gy = 0
        0x00, 0x00, // gz = 0
        0x94, 0x3C, // rawTemp = 15508 → ~37°C
      ];

      final data = TelemetryData.fromBytes(bytes);

      expect(data, isNotNull);
      expect(data!.ax, closeTo(1.0, 0.01));
      expect(data.rawIr, isNull);
      expect(data.rawRed, isNull);
      expect(data.rawTemp, equals(15508));
      expect(data.temperatureCelsius, isNotNull);
      expect(data.temperatureCelsius, closeTo(37.0, 0.1));
    });

    test('decodes valid 16-byte payload with bio sensor data', () {
      // 16-byte payload: IMU + Bio sensor
      // IR = 5000, RED = 3000
      final bytes = [
        0xE8, 0x03, // ax = 1000 → 1.0g
        0x00, 0x00, // ay = 0
        0x00, 0x00, // az = 0
        0x00, 0x00, // gx = 0
        0x00, 0x00, // gy = 0
        0x00, 0x00, // gz = 0
        0x88, 0x13, // IR = 5000
        0xB8, 0x0B, // RED = 3000
      ];

      final data = TelemetryData.fromBytes(bytes);

      expect(data, isNotNull);
      expect(data!.ax, closeTo(1.0, 0.01));
      expect(data.rawIr, equals(5000));
      expect(data.rawRed, equals(3000));
      expect(data.rawTemp, isNull);
    });

    test('handles bio sensor error value (65535)', () {
      // Bio sensor returns 65535 (0xFFFF) when disconnected
      final bytes = [
        0x00, 0x00, // ax
        0x00, 0x00, // ay
        0x00, 0x00, // az
        0x00, 0x00, // gx
        0x00, 0x00, // gy
        0x00, 0x00, // gz
        0xFF, 0xFF, // IR = 65535 (sensor error)
        0xFF, 0xFF, // RED = 65535 (sensor error)
      ];

      final data = TelemetryData.fromBytes(bytes);

      expect(data, isNotNull);
      expect(data!.rawIr, equals(65535));
      expect(data.rawRed, equals(65535));
    });

    test('magnitude calculation is correct', () {
      // At rest: ax=0, ay=0, az=1g → magnitude = 1
      final bytes = [
        0x00, 0x00, // ax = 0
        0x00, 0x00, // ay = 0
        0xE8, 0x03, // az = 1000 → 1.0g
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
      expect(TelemetryData.fromBytes(List.filled(15, 0)), isNull);
      expect(TelemetryData.fromBytes(List.filled(17, 0)), isNull);
      // Valid lengths: 12, 14, 16
      expect(TelemetryData.fromBytes(List.filled(12, 0)), isNotNull);
      expect(TelemetryData.fromBytes(List.filled(14, 0)), isNotNull);
      expect(TelemetryData.fromBytes(List.filled(16, 0)), isNotNull);
    });

    test('toString formats nicely with bio data', () {
      final bytes = [
        0xE8, 0x03, // ax = 1.0
        0x00, 0x00, // ay = 0.0
        0x00, 0x00, // az = 0.0
        0x00, 0x00, // gx = 0.0
        0x00, 0x00, // gy = 0.0
        0x00, 0x00, // gz = 0.0
        0x64, 0x00, // IR = 100
        0xC8, 0x00, // RED = 200
      ];

      final data = TelemetryData.fromBytes(bytes);
      expect(data.toString(), contains('A:(1.00'));
      expect(data.toString(), contains('IR:100'));
      expect(data.toString(), contains('RED:200'));
    });
    
    test('toString formats nicely with temperature data', () {
      // Raw value 15508 → ~37°C
      final bytes = [
        0xE8, 0x03, // ax = 1.0
        0x00, 0x00, // ay = 0.0
        0x00, 0x00, // az = 0.0
        0x00, 0x00, // gx = 0.0
        0x00, 0x00, // gy = 0.0
        0x00, 0x00, // gz = 0.0
        0x94, 0x3C, // rawTemp = 15508
      ];

      final data = TelemetryData.fromBytes(bytes);
      expect(data.toString(), contains('A:(1.00'));
      expect(data.toString(), contains('TEMP:'));
      expect(data.toString(), contains('°C'));
    });
  });
}


