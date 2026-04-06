import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/device/device_service.dart';

/// Configuration for a minigame screen.
class MinigameConfig {
  final String title;
  final bool keepScreenOn;
  final List<DeviceOrientation>? forcedOrientations;
  final bool showAppBar;

  const MinigameConfig({
    required this.title,
    this.keepScreenOn = true,
    this.forcedOrientations,
    this.showAppBar = false,
  });
}

/// Generic wrapper for minigame screens.
/// Provides common functionality: wakelock, orientation locking, scaffold.
class MinigameScreen extends StatefulWidget {
  final MinigameConfig config;
  final Widget gameWidget;
  final Widget? overlay;
  final VoidCallback? onDispose;

  const MinigameScreen({
    super.key,
    required this.config,
    required this.gameWidget,
    this.overlay,
    this.onDispose,
  });

  @override
  State<MinigameScreen> createState() => _MinigameScreenState();
}

class _MinigameScreenState extends State<MinigameScreen> {
  @override
  void initState() {
    super.initState();
    // Always keep screen on for minigames
    WakelockPlus.enable();
    DeviceService().registerMinigameStart();
    
    // Lock orientation if specified
    if (widget.config.forcedOrientations != null) {
      SystemChrome.setPreferredOrientations(widget.config.forcedOrientations!);
    }
  }

  @override
  void dispose() {
    // Disable wakelock and unregister minigame
    WakelockPlus.disable();
    DeviceService().registerMinigameEnd();
    
    // Restore all orientations
    if (widget.config.forcedOrientations != null) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    
    // Call custom dispose callback
    widget.onDispose?.call();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body = Stack(
      children: [
        widget.gameWidget,
        if (widget.overlay != null) widget.overlay!,
      ],
    );

    if (widget.config.showAppBar) {
      return Scaffold(
        backgroundColor: const Color(0xFF222222),
        appBar: AppBar(
          title: Text(
            widget.config.title,
            style: const TextStyle(fontFamily: 'Monocraft'),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: body,
      );
    }

    return Scaffold(body: body);
  }
}
