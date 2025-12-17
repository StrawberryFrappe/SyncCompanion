import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'bob_the_blob.dart';
import 'pets/pet.dart';

/// VirtualPetGame - The main Flame game instance.
/// Renders a retro GameBoy-green background with the virtual pet centered.
class VirtualPetGame extends FlameGame {
  // Classic GameBoy screen green
  static const Color gameBoyGreen = Color(0xFF9BBC0F);

  /// The current pet instance
  Pet? _currentPet;
  Pet get currentPet => _currentPet!;
  
  final Completer<void> _initialized = Completer<void>();
  Future<void> get initialized => _initialized.future;
  
  /// Whether the device is currently synced (updated from outside)
  bool isDeviceSynced = false;

  @override
  Color backgroundColor() => gameBoyGreen;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Create BobTheBlob and center him
    _currentPet = BobTheBlob()
      ..position = size / 2
      ..isDeviceSyncedCallback = () => isDeviceSynced;
    
    add(_currentPet!);
    _initialized.complete();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    
    // Re-center pet when screen resizes
    for (final component in children.whereType<Pet>()) {
      component.position = size / 2;
    }
  }

  /// Update the sync status from external source (BLE connection)
  void setSyncStatus(bool synced) {
    isDeviceSynced = synced;
  }

  /// Get current pet stats for display in DevTools
  Map<String, double> getStatValues() {
    return {
      'hunger': currentPet.stats.hunger,
      'happiness': currentPet.stats.happiness,
      'wellbeing': currentPet.stats.overallWellbeing,
    };
  }

  /// Get current stat rates for display in DevTools
  Map<String, double> getStatRates() {
    return {
      'hungerDecayRate': currentPet.stats.hungerDecayRate,
      'happinessGainRate': currentPet.stats.happinessGainRate,
      'happinessDecayRate': currentPet.stats.happinessDecayRate,
    };
  }

  /// Update stat rates from DevTools
  void setStatRates({
    double? hungerDecayRate,
    double? happinessGainRate,
    double? happinessDecayRate,
  }) {
    if (hungerDecayRate != null) {
      currentPet.stats.hungerDecayRate = hungerDecayRate;
    }
    if (happinessGainRate != null) {
      currentPet.stats.happinessGainRate = happinessGainRate;
    }
    if (happinessDecayRate != null) {
      currentPet.stats.happinessDecayRate = happinessDecayRate;
    }
  }

  /// Feed the pet
  void feedPet({double amount = 0.25}) {
    currentPet.stats.feed(amount: amount);
  }

  /// Reset pet stats to full
  void resetPetStats() {
    currentPet.stats.reset();
  }

  /// Save pet stats to SharedPreferences
  Future<void> savePetStats() async {
    if (!_initialized.isCompleted) return;
    await _currentPet!.stats.saveToPrefs();
  }

  /// Load pet stats from SharedPreferences and apply background updates
  Future<void> loadPetStats({required bool isDeviceSynced}) async {
    await initialized;
    await _currentPet!.stats.loadFromPrefs(isDeviceSynced: isDeviceSynced);
  }

  /// Get happiness buffer value for display
  double get happinessBuffer => currentPet.stats.happinessBuffer;
}
