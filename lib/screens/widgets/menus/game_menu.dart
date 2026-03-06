import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';

/// Data class for game items in the menu
class GameMenuItem {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  
  const GameMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Game menu widget (similar to Wardrobe/Food Store).
class GameMenu extends StatelessWidget {
  final VoidCallback onClose;
  final Function(String gameId) onPlay;

  const GameMenu({
    super.key,
    required this.onClose,
    required this.onPlay,
  });

  static const List<GameMenuItem> games = [
    GameMenuItem(
      id: 'flappy_bird',
      name: 'Flappy Bob',
      description: 'Shake or tap to fly!',
      icon: Icons.flutter_dash,
      color: Color(0xFF87CEEB),
    ),
    GameMenuItem(
      id: 'orchestra',
      name: 'Orchestra',
      description: 'Make your pets sing!',
      icon: Icons.music_note,
      color: Color(0xFF9C27B0),
    ),
    GameMenuItem(
      id: 'donut',
      name: 'donut.dart',
      description: 'Zero gravity pastry',
      icon: Icons.donut_large,
      color: Color(0xFFE91E63),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(width: 4, color: Colors.black),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.games,
                      style: TextStyle(
                        fontFamily: 'Monocraft',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(thickness: 2, color: Colors.black),
              const SizedBox(height: 12),
              
              // Grid of games
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  return _buildGameCard(game);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGameCard(GameMenuItem game) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: game.color.withAlpha((0.2 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 2, color: Colors.black),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(game.icon, size: 32, color: game.color.withAlpha((0.8 * 255).toInt())),
            const SizedBox(height: 2),
            Text(
              game.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade100,
                foregroundColor: Colors.green.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                minimumSize: Size.zero,
                side: const BorderSide(color: Colors.green),
              ),
              onPressed: () => onPlay(game.id),
              child: const Text('PLAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
