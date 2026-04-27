import 'package:shared_preferences/shared_preferences.dart';

/// Runtime game settings that are persisted to SharedPreferences.
class GameSettings {
  static double sbrUpwardSpeedMultiplier = 1.5;

  static const _prefsKey = 'sbr_upward_speed_multiplier';

  /// Load persisted settings. Call once at app start or when needed.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    sbrUpwardSpeedMultiplier = prefs.getDouble(_prefsKey) ?? sbrUpwardSpeedMultiplier;
  }

  /// Persist and apply multiplier.
  static Future<void> setSbrUpwardSpeedMultiplier(double v) async {
    sbrUpwardSpeedMultiplier = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, v);
  }
}
