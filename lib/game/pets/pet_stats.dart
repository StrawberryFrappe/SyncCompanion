import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Manages the hunger and happiness stats for a pet.
/// Stats trickle over time based on configurable rates.
/// Supports persistence for background stat updates.
class PetStats {
  /// Hunger level: 0.0 (starving) to 1.0 (full)
  double _hunger;
  
  /// Happiness level: 0.0 (miserable) to 1.0 (ecstatic)
  double _happiness;
  
  /// Happiness buffer accumulated while app was in background and linked
  double _happinessBuffer;

  /// Rate at which hunger decreases per second (always active)
  double hungerDecayRate;
  
  /// Rate at which happiness increases per second (when device is synced)
  double happinessGainRate;
  
  /// Rate at which happiness decreases per second (when device is NOT synced)
  double happinessDecayRate;
  
  /// Timestamp of last update (for background calculations)
  DateTime _lastUpdateTime;
  
  /// Callback triggered when wellbeing drops below threshold
  void Function()? onLowWellbeing;
  
  /// Threshold for low wellbeing notification (0.0 to 1.0)
  double lowWellbeingThreshold;
  
  /// Whether low wellbeing notification was already sent (resets when recovered)
  bool _lowWellbeingNotified = false;

  /// Gold coins (for clothing)
  int _goldCoins = 0;
  
  /// Silver coins (for food)
  int _silverCoins = 0;

  /// IDs of unlocked clothing items
  List<String> _unlockedClothingIds = [];

  /// Map of slot name to clothing ID for equipped items
  Map<String, String> _equippedClothing = {};

  PetStats({
    double hunger = 1.0,
    double happiness = 1.0,
    double happinessBuffer = 0.0,
    int goldCoins = 0,
    int silverCoins = 0,
    List<String>? unlockedClothingIds,
    Map<String, String>? equippedClothing,
    this.hungerDecayRate = 0.01,
    this.happinessGainRate = 0.02,
    this.happinessDecayRate = 0.01,
    this.lowWellbeingThreshold = 0.25,
    DateTime? lastUpdateTime,
  })  : _hunger = hunger.clamp(0.0, 1.0),
        _happiness = happiness.clamp(0.0, 1.0),
        _happinessBuffer = happinessBuffer.clamp(0.0, 1.0),
        _goldCoins = goldCoins,
        _silverCoins = silverCoins,
        _unlockedClothingIds = unlockedClothingIds ?? [],
        _equippedClothing = equippedClothing ?? {},
        _lastUpdateTime = lastUpdateTime ?? DateTime.now();

  // ============ GETTERS ============
  
  /// Current hunger value (0.0 to 1.0)
  double get hunger => _hunger;
  
  /// Current happiness value (0.0 to 1.0)
  double get happiness => _happiness;
  
  /// Current happiness buffer (accumulated while linked in background)
  double get happinessBuffer => _happinessBuffer;

  /// Current gold coins (Clothing)
  int get goldCoins => _goldCoins;

  /// Current silver coins (Food)
  int get silverCoins => _silverCoins;

  /// Overall wellbeing: average of hunger and happiness (0.0 to 1.0)
  double get overallWellbeing => (_hunger + _happiness) / 2.0;

  /// IDs of unlocked clothing items
  List<String> get unlockedClothingIds => List.unmodifiable(_unlockedClothingIds);
  
  /// Map of slot name to clothing ID for equipped items
  Map<String, String> get equippedClothing => Map.unmodifiable(_equippedClothing);

  // ============ SETTERS ============

  /// Set hunger directly (clamped to 0.0-1.0)
  set hunger(double value) => _hunger = value.clamp(0.0, 1.0);
  
  /// Set happiness directly (clamped to 0.0-1.0)
  set happiness(double value) => _happiness = value.clamp(0.0, 1.0);

  // ============ STAT UPDATE METHODS ============

  /// Update stats based on elapsed time (for real-time updates while app is active).
  /// [dt] is the time delta in seconds.
  /// [isDeviceSynced] determines if happiness increases or decreases.
  void update(double dt, {required bool isDeviceSynced}) {
    // Hunger always decreases
    _hunger = max(0.0, _hunger - (hungerDecayRate * dt));

    // Happiness changes based on sync status
    if (isDeviceSynced) {
      _happiness = min(1.0, _happiness + (happinessGainRate * dt));
    } else {
      _happiness = max(0.0, _happiness - (happinessDecayRate * dt));
    }
    
    // Check for low wellbeing threshold crossing
    _checkLowWellbeing();
  }
  
  /// Check if wellbeing has dropped below threshold and trigger callback
  void _checkLowWellbeing() {
    final wellbeing = overallWellbeing;
    
    if (wellbeing <= lowWellbeingThreshold) {
      if (!_lowWellbeingNotified) {
        _lowWellbeingNotified = true;
        onLowWellbeing?.call();
      }
    } else {
      _lowWellbeingNotified = false;
    }
  }

  /// Calculate and apply stats changes that occurred while app was in background.
  void applyBackgroundUpdates({required bool wasDeviceSynced}) {
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;
    
    if (elapsedSeconds <= 0) return;
    
    final hungerDelta = hungerDecayRate * elapsedSeconds;
    final happinessDelta = happinessDecayRate * elapsedSeconds;
    
    _hunger = max(0.0, _hunger - hungerDelta);
    _happiness = max(0.0, _happiness - happinessDelta);
    
    if (wasDeviceSynced) {
      _happinessBuffer = min(1.0, _happinessBuffer + (happinessGainRate * elapsedSeconds));
    }
    
    _lastUpdateTime = now;
  }

  /// Apply the accumulated happiness buffer to the happiness stat.
  void applyHappinessBuffer() {
    if (_happinessBuffer > 0) {
      _happiness = min(1.0, _happiness + _happinessBuffer);
      _happinessBuffer = 0.0;
    }
  }

  /// Feed the pet - increases hunger by amount
  void feed({double amount = 0.25}) {
    _hunger = min(1.0, _hunger + amount);
  }

  /// Reset stats to full
  void reset() {
    _hunger = 1.0;
    _happiness = 1.0;
    _happinessBuffer = 0.0;
    _lastUpdateTime = DateTime.now();
  }

  // ============ MONEY METHODS ============

  /// Add gold coins
  void addGold(int amount) {
    if (amount > 0) {
      _goldCoins += amount;
    }
  }

  /// Spend gold coins. Returns true if successful.
  bool spendGold(int amount) {
    if (amount > 0 && _goldCoins >= amount) {
      _goldCoins -= amount;
      return true;
    }
    return false;
  }

  /// Add silver coins
  void addSilver(int amount) {
    if (amount > 0) {
      _silverCoins += amount;
    }
  }

  /// Spend silver coins. Returns true if successful.
  bool spendSilver(int amount) {
    if (amount > 0 && _silverCoins >= amount) {
      _silverCoins -= amount;
      return true;
    }
    return false;
  }

  // ============ CLOTHING METHODS ============

  /// Unlock a clothing item
  void unlockClothing(String id) {
    if (!_unlockedClothingIds.contains(id)) {
      _unlockedClothingIds.add(id);
    }
  }

  /// Check if clothing is unlocked
  bool isClothingUnlocked(String id) => _unlockedClothingIds.contains(id);

  /// Equip clothing item (replaces existing item in same slot)
  void equipClothing(String slotName, String id) {
    _equippedClothing[slotName] = id;
  }

  /// Unequip clothing from slot
  void unequipClothing(String slotName) {
    _equippedClothing.remove(slotName);
  }

  // ============ PERSISTENCE ============

  /// Save current state to SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    _lastUpdateTime = DateTime.now();
    
    await prefs.setDouble('pet_hunger', _hunger);
    await prefs.setDouble('pet_happiness', _happiness);
    await prefs.setDouble('pet_happiness_buffer', _happinessBuffer);
    await prefs.setInt('pet_gold_coins', _goldCoins);
    await prefs.setInt('pet_silver_coins', _silverCoins);
    await prefs.setStringList('pet_unlocked_clothing', _unlockedClothingIds);
    final equippedList = _equippedClothing.entries.map((e) => '${e.key}:${e.value}').toList();
    await prefs.setStringList('pet_equipped_clothing', equippedList);
    await prefs.setInt('pet_last_update', _lastUpdateTime.millisecondsSinceEpoch);
  }

  /// Load state from SharedPreferences and apply background updates
  Future<void> loadFromPrefs({required bool isDeviceSynced}) async {
    final prefs = await SharedPreferences.getInstance();
    
    _hunger = prefs.getDouble('pet_hunger') ?? _hunger;
    _happiness = prefs.getDouble('pet_happiness') ?? _happiness;
    _happinessBuffer = prefs.getDouble('pet_happiness_buffer') ?? 0.0;
    _goldCoins = prefs.getInt('pet_gold_coins') ?? 0;
    _silverCoins = prefs.getInt('pet_silver_coins') ?? 0;
    _unlockedClothingIds = prefs.getStringList('pet_unlocked_clothing') ?? [];
    
    final equippedList = prefs.getStringList('pet_equipped_clothing') ?? [];
    _equippedClothing.clear();
    for (final entry in equippedList) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        _equippedClothing[parts[0]] = parts[1];
      }
    }
    
    final lastUpdateMs = prefs.getInt('pet_last_update');
    
    if (lastUpdateMs != null) {
      _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
      applyBackgroundUpdates(wasDeviceSynced: isDeviceSynced);
      if (isDeviceSynced) applyHappinessBuffer();
    }
    
    await saveToPrefs();
  }

  /// Create a copy with modified values
  PetStats copyWith({
    double? hunger,
    double? happiness,
    double? happinessBuffer,
    int? goldCoins,
    int? silverCoins,
    List<String>? unlockedClothingIds,
    Map<String, String>? equippedClothing,
    double? hungerDecayRate,
    double? happinessGainRate,
    double? happinessDecayRate,
  }) {
    return PetStats(
      hunger: hunger ?? _hunger,
      happiness: happiness ?? _happiness,
      happinessBuffer: happinessBuffer ?? _happinessBuffer,
      goldCoins: goldCoins ?? _goldCoins,
      silverCoins: silverCoins ?? _silverCoins,
      unlockedClothingIds: unlockedClothingIds ?? List.from(_unlockedClothingIds),
      equippedClothing: equippedClothing ?? Map.from(_equippedClothing),
      hungerDecayRate: hungerDecayRate ?? this.hungerDecayRate,
      happinessGainRate: happinessGainRate ?? this.happinessGainRate,
      happinessDecayRate: happinessDecayRate ?? this.happinessDecayRate,
    );
  }

  @override
  String toString() =>
      'PetStats(hunger: ${(_hunger * 100).toStringAsFixed(1)}%, '
      'happiness: ${(_happiness * 100).toStringAsFixed(1)}%, '
      'gold: $_goldCoins, silver: $_silverCoins)';
}
