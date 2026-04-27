import 'package:flutter_test/flutter_test.dart';
import 'package:Therapets/services/device/bio_signal_processor.dart';
import 'package:Therapets/services/device/temperature_signal_processor.dart';

void main() {
  group('Last Reading Retention', () {
    test('BioSignalProcessor retains last valid reading', () {
      final processor = BioSignalProcessor();
      
      // Process some raw IR/Red values
      processor.process(10000, 8000);
      
      // Verify last valid reading is stored when we get valid vitals
      processor.preSeed(75, 98);
      
      final lastReading = processor.lastValidBioData;
      expect(lastReading, isNotNull);
      expect(lastReading!.bpm, 75);
      expect(lastReading!.spo2, 98);
      expect(processor.lastValidBioDataTimestamp, isNotNull);
      
      processor.dispose();
    });
    
    test('BioSignalProcessor getFreshValidReading returns reading within timeout', () {
      final processor = BioSignalProcessor();
      
      processor.preSeed(75, 98);
      
      // Should return reading (just created, well within 60 second timeout)
      final freshReading = processor.getFreshValidReading();
      expect(freshReading, isNotNull);
      expect(freshReading!.bpm, 75);
      
      processor.dispose();
    });
    
    test('BioSignalProcessor getFreshValidReading returns null when empty', () {
      final processor = BioSignalProcessor();
      
      // No reading ever stored
      final freshReading = processor.getFreshValidReading();
      expect(freshReading, isNull);
      
      processor.dispose();
    });
    
    test('TemperatureSignalProcessor retains last valid reading', () {
      final processor = TemperatureSignalProcessor();
      
      // Process a temperature value in valid range (29.7°C to 41°C)
      // Raw temp: (35°C + 273.15) / 0.02 = 15407.5
      processor.process(15408);
      
      // Check that we have the reading
      final lastReading = processor.lastValidData;
      expect(lastReading, isNotNull);
      expect(lastReading!.temperatureCelsius, closeTo(35.0, 0.2));
      expect(processor.lastValidDataTimestamp, isNotNull);
      
      processor.dispose();
    });
    
    test('TemperatureSignalProcessor getFreshValidReading returns reading within timeout', () {
      final processor = TemperatureSignalProcessor();
      
      // Valid temperature
      processor.process(15408);
      
      final freshReading = processor.getFreshValidReading();
      expect(freshReading, isNotNull);
      expect(freshReading!.temperatureCelsius, closeTo(35.0, 0.2));
      
      processor.dispose();
    });
    
    test('TemperatureSignalProcessor clears last reading on reset', () {
      final processor = TemperatureSignalProcessor();
      
      processor.process(15408);
      expect(processor.lastValidData, isNotNull);
      
      processor.reset();
      expect(processor.lastValidData, isNull);
      expect(processor.lastValidDataTimestamp, isNull);
      
      processor.dispose();
    });
    
    test('BioSignalProcessor clears last reading on reset', () {
      final processor = BioSignalProcessor();
      
      processor.preSeed(75, 98);
      expect(processor.lastValidBioData, isNotNull);
      
      processor.reset();
      expect(processor.lastValidBioData, isNull);
      expect(processor.lastValidBioDataTimestamp, isNull);
      
      processor.dispose();
    });
  });
}
