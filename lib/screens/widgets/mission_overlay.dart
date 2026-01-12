import 'dart:math';

import 'package:flutter/material.dart';
import '../../game/missions/mission.dart';
import '../../services/mission_service.dart';

class MissionOverlay extends StatefulWidget {
  const MissionOverlay({super.key});

  @override
  State<MissionOverlay> createState() => _MissionOverlayState();
}

class _MissionOverlayState extends State<MissionOverlay> with SingleTickerProviderStateMixin {
  final MissionService _service = MissionService();
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    
    // Listen for completion events to show banners
    _service.missionCompletions.listen(_showCompletionBanner);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _showCompletionBanner(Mission mission) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mission Completed!', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(mission.title),
                ],
              ),
            ),
            Text('+${mission.goldReward} Gold', style: const TextStyle(color: Colors.amber)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey[900],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Mission>>(
      stream: _service.missionUpdates,
      initialData: _service.activeMissions,
      builder: (context, snapshot) {
        final missions = snapshot.data ?? [];
        final completedCount = missions.where((m) => m.isCompleted).length;
        final totalCount = missions.length;
        final allDone = totalCount > 0 && completedCount == totalCount;

        return Stack(
          alignment: Alignment.topRight,
          children: [
             // The toggle button
            GestureDetector(
              onTap: _toggleExpanded,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: allDone ? Colors.green : const Color(0xE6FFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(width: 2, color: Colors.black),
                ),
                child: Icon(
                  allDone ? Icons.star : Icons.assignment,
                  color: allDone ? Colors.white : Colors.black,
                  size: 24,
                ),
              ),
            ),
            
            // Expanded card list
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 280,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(width: 2, color: Colors.black),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Daily Missions', 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text('$completedCount/$totalCount',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const Divider(thickness: 2),
                        const SizedBox(height: 8),
                        if (missions.isEmpty)
                          const Text('No missions available today.'),
                        ...missions.map((mission) => _buildMissionItem(mission)),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Notification badge if tasks pending
            if (!allDone && !_isExpanded && totalCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMissionItem(Mission mission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: mission.isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: mission.isCompleted ? Colors.green : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                mission.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: mission.isCompleted ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: mission.isCompleted ? TextDecoration.lineThrough : null,
                    color: mission.isCompleted ? Colors.grey : Colors.black,
                  ),
                ),
              ),
              if (!mission.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text('${mission.goldReward}'),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(mission.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          if (!mission.isCompleted)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: mission.progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 6,
              ),
            ),
        ],
      ),
    );
  }
}
