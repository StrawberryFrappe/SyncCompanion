import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/device/device_service.dart';
import 'ecg_waveform.dart';

/// Dedicated screen for viewing pulse oximeter data.
/// 
/// Displays:
/// - ECG-style real-time waveform of filtered IR signal
/// - Heart rate (BPM) with heart icon
/// - SpO2 percentage with O₂ icon
/// - Sensor status indicators
class PulseOximeterScreen extends StatefulWidget {
  final DeviceService device;
  
  const PulseOximeterScreen({
    super.key,
    required this.device,
  });
  
  @override
  State<PulseOximeterScreen> createState() => _PulseOximeterScreenState();
}

class _PulseOximeterScreenState extends State<PulseOximeterScreen> {
  StreamSubscription<BioData>? _bioSub;
  BioData _latestData = const BioData();
  List<double> _waveformData = [];
  
  // Update timer for smooth waveform updates
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Subscribe to bio data stream
    _bioSub = widget.device.bioData$.listen((data) {
      _latestData = data;
    });
    
    // Update UI at ~30fps for smooth waveform
    _updateTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        setState(() {
          _waveformData = widget.device.waveformData;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    _bioSub?.cancel();
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
            Icon(Icons.monitor_heart, color: Color(0xFF00FF00)),
            SizedBox(width: 8),
            Text(
              'PULSE OXIMETER',
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
              // Status bar at top for visibility
              _buildStatusBar(),
              
              const SizedBox(height: 16),
              
              // ECG Waveform
              Expanded(
                child: _buildWaveformSection(),
              ),
              
              const SizedBox(height: 16),
              
              // Vitals display (BPM and SpO2)
              _buildVitalsRow(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildVitalsRow() {
    return Row(
      children: [
        // Heart Rate
        Expanded(
          child: _VitalCard(
            icon: Icons.favorite,
            iconColor: const Color(0xFFFF4444),
            label: 'HEART RATE',
            value: _latestData.bpm > 0 ? '${_latestData.bpm}' : '--',
            unit: 'BPM',
            isActive: _latestData.sensorConnected && _latestData.bpm > 0,
          ),
        ),
        
        const SizedBox(width: 16),
        
        // SpO2
        Expanded(
          child: _VitalCard(
            icon: Icons.air,
            iconColor: const Color(0xFF4488FF),
            label: 'OXYGEN',
            value: _latestData.spo2 > 0 ? '${_latestData.spo2}' : '--',
            unit: '%SpO₂',
            isActive: _latestData.sensorConnected && _latestData.spo2 > 0,
          ),
        ),
      ],
    );
  }
  
  Widget _buildWaveformSection() {
    // Sensor disconnected
    if (!_latestData.sensorConnected) {
      return const NoSignalIndicator();
    }
    
    // Sensor initializing (raw values are 0)
    if (_latestData.rawIr == 0 && _latestData.rawRed == 0) {
      return const InitializingIndicator();
    }
    
    // Show waveform
    if (_waveformData.isEmpty) {
      return const InitializingIndicator();
    }
    
    return EcgWaveform(
      data: _waveformData,
      lineColor: const Color(0xFF00FF00),
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
    } else if (_latestData.rawIr == 0) {
      statusColor = const Color(0xFF888888);
      statusText = 'INITIALIZING...';
      statusIcon = Icons.hourglass_empty;
    } else if (!_latestData.fingerDetected) {
      statusColor = const Color(0xFFFFAA00);
      statusText = 'PLACE FINGER ON SENSOR';
      statusIcon = Icons.touch_app;
    } else if (_latestData.humanDetected) {
      statusColor = const Color(0xFF00FF00);
      statusText = 'SIGNAL GOOD';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = const Color(0xFFFFAA00);
      statusText = 'DETECTING HEARTBEAT...';
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
          if (_latestData.sensorConnected) ...[
            const SizedBox(height: 4),
            Text(
              'IR: ${_latestData.rawIr ?? 0}  RED: ${_latestData.rawRed ?? 0}',
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

/// Card widget for displaying a vital sign.
class _VitalCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;
  final bool isActive;
  
  const _VitalCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
    required this.isActive,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? iconColor.withAlpha(100) : const Color(0xFF333333),
          width: 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: iconColor.withAlpha(30),
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
                icon,
                color: isActive ? iconColor : Colors.grey.shade700,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.grey.shade400 : Colors.grey.shade700,
                  fontSize: 10,
                  fontFamily: 'Monocraft',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade700,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                fontFamily: 'Monocraft',
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: isActive ? iconColor : Colors.grey.shade700,
              fontSize: 14,
              fontFamily: 'Monocraft',
            ),
          ),
        ],
      ),
    );
  }
}
