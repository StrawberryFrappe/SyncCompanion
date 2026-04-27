import 'package:flutter_test/flutter_test.dart';
import 'package:Therapets/services/device/device_service.dart';
import 'package:Therapets/services/device/device_status_aggregator.dart';

void main() {
  group('DeviceStatusAggregator rehydration', () {
    test('clears synced on app rehydration until fresh telemetry returns', () {
      DeviceDisplayStatus baseStatus = DeviceDisplayStatus.connected;
      DeviceDisplayStatus staleStatus = DeviceDisplayStatus.waiting;
      bool hasRecentTelemetry = true;
      bool humanDetected = true;
      bool minigameRunning = false;

      final aggregator = DeviceStatusAggregator(
        baseStatusProvider: () => baseStatus,
        staleStatusProvider: () => staleStatus,
        isHumanDetectedProvider: () => humanDetected,
        isMinigameRunningProvider: () => minigameRunning,
        hasRecentTelemetryProvider: () => hasRecentTelemetry,
      );

      // With connected base + fresh telemetry + human detected, status is synced.
      expect(aggregator.currentDisplayStatus, DeviceDisplayStatus.synced);

      // Simulate app closure/rehydration: stale telemetry until first fresh packet.
      hasRecentTelemetry = false;
      aggregator.reset();
      expect(aggregator.currentDisplayStatus, DeviceDisplayStatus.waiting);

      // Simulate first fresh telemetry packet after resume.
      hasRecentTelemetry = true;
      aggregator.handleHumanDetectionChange(true);
      expect(aggregator.currentDisplayStatus, DeviceDisplayStatus.synced);

      aggregator.dispose();
    });
  });
}
