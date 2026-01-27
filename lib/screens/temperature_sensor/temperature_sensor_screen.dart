import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/device/device_service.dart';
import 'temperature_waveform.dart';

/// Dedicated screen for viewing GY906 temperature sensor data.
/// 
/// Displays:
/// - Temperature trend waveform over time
/// - Current temperature reading in Celsius
/// - Sensor status indicators
class TemperatureSensorScreen extends StatefulWidget {
  final DeviceService device;
  
  const TemperatureSensorScreen({
    super.key,
    required this.device,
  });
  
  @override
  State<TemperatureSensorScreen> createState() => _TemperatureSensorScreenState();
}

class _TemperatureSensorScreenState extends State<TemperatureSensorScreen> {
  StreamSubscription<TemperatureData>? _tempSub;
  TemperatureData _latestData = const TemperatureData();
  List<double> _waveformData = [];
  
  // Update timer for smooth waveform updates
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Subscribe to temperature data stream
    _tempSub = widget.device.temperatureData$.listen((data) {
      _latestData = data;
    });
    
    // Update UI at ~30fps for smooth waveform
    _updateTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        setState(() {
          _waveformData = widget.device.temperatureWaveformData;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    _tempSub?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.thermostat, color: Color(0xFFFF6600)),
            SizedBox(width: 8),
            Text(
              'TEMPERATURE SENSOR',
              style: TextStyle(
                fontFamily: 'Monocraft',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Status bar at top
              _buildStatusBar(),
              
              const SizedBox(height: 16),
              
              // Temperature Waveform
              Expanded(
                child: _buildWaveformSection(),
              ),
              
              const SizedBox(height: 16),
              
              // Temperature display
              _buildTemperatureCard(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTemperatureCard() {
    final temp = _latestData.temperatureCelsius;
    final isActive = _latestData.sensorConnected && temp != null;
    final displayValue = temp != null ? temp.toStringAsFixed(1) : '--';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFFFF6600).withAlpha(100) : const Color(0xFF333333),
          width: 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFFF6600).withAlpha(30),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.thermostat,
                color: isActive ? const Color(0xFFFF6600) : Colors.grey.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'TEMPERATURE',
                style: TextStyle(
                  color: isActive ? Colors.grey.shade400 : Colors.grey.shade700,
                  fontSize: 12,
                  fontFamily: 'Monocraft',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey.shade700,
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Monocraft',
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '°C',
                    style: TextStyle(
                      color: isActive ? const Color(0xFFFF6600) : Colors.grey.shade700,
                      fontSize: 24,
                      fontFamily: 'Monocraft',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_latestData.humanDetected) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF00).withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF00FF00).withAlpha(100)),
              ),
              child: const Text(
                'HUMAN DETECTED',
                style: TextStyle(
                  color: Color(0xFF00FF00),
                  fontSize: 10,
                  fontFamily: 'Monocraft',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildWaveformSection() {
    // Sensor disconnected
    if (!_latestData.sensorConnected) {
      return const _NoTempSignalIndicator();
    }
    
    // Sensor initializing (temperature is null or zero)
    if (_latestData.temperatureCelsius == null) {
      return const _TempInitializingIndicator();
    }
    
    // Show waveform
    if (_waveformData.isEmpty) {
      return const _TempInitializingIndicator();
    }
    
    return TemperatureWaveform(
      data: _waveformData,
      lineColor: const Color(0xFFFF6600),
    );
  }
  
  Widget _buildStatusBar() {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (!_latestData.sensorConnected) {
      statusColor = const Color(0xFFFF4444);
      statusText = 'SENSOR DISCONNECTED';
      statusIcon = Icons.sensors_off;
    } else if (_latestData.temperatureCelsius == null) {
      statusColor = const Color(0xFF888888);
      statusText = 'INITIALIZING...';
      statusIcon = Icons.hourglass_empty;
    } else if (_latestData.humanDetected) {
      statusColor = const Color(0xFF00FF00);
      statusText = 'SIGNAL GOOD';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = const Color(0xFFFFAA00);
      statusText = 'DETECTING...';
      statusIcon = Icons.sensors;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withAlpha(100), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontFamily: 'Monocraft',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_latestData.sensorConnected && _latestData.rawTemp != null) ...[
            const SizedBox(height: 4),
            Text(
              'RAW: ${_latestData.rawTemp}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget that displays no signal / sensor disconnected state for temperature.
class _NoTempSignalIndicator extends StatelessWidget {
  const _NoTempSignalIndicator();
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A1A1A), width: 2),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.thermostat,
              size: 48,
              color: Color(0xFFFF4444),
            ),
            SizedBox(height: 8),
            Text(
              'SENSOR DISCONNECTED',
              style: TextStyle(
                color: Color(0xFFFF4444),
                fontSize: 14,
                fontFamily: 'Monocraft',
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Point the sensor at your body',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget that displays when temperature sensor is initializing.
class _TempInitializingIndicator extends StatelessWidget {
  const _TempInitializingIndicator();
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A2A1A), width: 2),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFFFF6600),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'INITIALIZING SENSOR',
              style: TextStyle(
                color: Color(0xFFFF6600),
                fontSize: 14,
                fontFamily: 'Monocraft',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
