import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Therapets/l10n/app_localizations.dart';
import '../../../game/missions/daily_missions.dart';
import '../../../game/missions/mission.dart';
import '../../../game/missions/mission_service.dart';

class MissionOverlay extends StatefulWidget {
  const MissionOverlay({super.key});

  @override
  State<MissionOverlay> createState() => _MissionOverlayState();
}

class _MissionOverlayState extends State<MissionOverlay> with SingleTickerProviderStateMixin {
  late MissionService _service;
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service = context.read<MissionService>();
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

  /// Returns the localized title for a mission based on its id.
  String _missionTitle(AppLocalizations l10n, Mission mission) {
    switch (mission.id) {
      case 'mission_sync_duration':
        return l10n.missionSyncMasterTitle;
      case 'mission_minigame_play':
        return l10n.missionGameTimeTitle;
      case 'mission_feed_pet':
        return l10n.missionYummyTimeTitle;
      default:
        return mission.title;
    }
  }

  /// Returns the localized description for a mission based on its id.
  String _missionDesc(AppLocalizations l10n, Mission mission) {
    if (mission is SyncDurationMission) {
      final minutes = (mission.targetDuration / 60).ceil();
      return l10n.missionSyncMasterDesc(minutes);
    } else if (mission is MinigamePlayMission) {
      return l10n.missionGameTimeDesc(mission.targetPlays);
    } else if (mission is FeedPetMission) {
      return l10n.missionYummyTimeDesc(mission.targetFeeds);
    }
    return mission.description;
  }

  void _showCompletionBanner(Mission mission) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

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
                  Text(l10n.missionCompleted, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(_missionTitle(l10n, mission)),
                ],
              ),
            ),
            Text(l10n.goldReward(mission.goldReward), style: const TextStyle(color: Colors.amber)),
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

        return TapRegion(
          onTapOutside: (_) {
            if (_isExpanded) {
              _toggleExpanded();
            }
          },
          child: Stack(
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
              // Expanded card list
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Visibility(
                    visible: _controller.status != AnimationStatus.dismissed,
                    child: child!,
                  );
                },
                child: Padding(
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
                            color: Colors.black.withValues(alpha: 0.2),
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
                              Text(AppLocalizations.of(context)!.dailyMissions, 
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text('$completedCount/$totalCount',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          const Divider(thickness: 2),
                          const SizedBox(height: 8),
                          if (missions.isEmpty)
                            Text(AppLocalizations.of(context)!.noMissionsAvailable),
                          ...missions.map((mission) => _buildMissionItem(mission)),
                        ],
                      ),
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
          ),
        );
      },
    );
  }

  Widget _buildMissionItem(Mission mission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: mission.isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: mission.isCompleted ? Colors.green : Colors.grey.withValues(alpha: 0.3),
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
                child: Builder(builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return Text(
                    _missionTitle(l10n, mission),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: mission.isCompleted ? TextDecoration.lineThrough : null,
                      color: mission.isCompleted ? Colors.grey : Colors.black,
                    ),
                  );
                }),
              ),
              if (!mission.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
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
          Builder(builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Text(_missionDesc(l10n, mission), style: const TextStyle(fontSize: 12, color: Colors.grey));
          }),
          const SizedBox(height: 6),
          if (!mission.isCompleted)
             Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${mission.currentValue} / ${mission.targetValue} ${mission.valueUnit}'.trim(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}
