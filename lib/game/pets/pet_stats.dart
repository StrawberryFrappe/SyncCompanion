import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

part 'pet_stats.g.dart';

/// Manages the hunger and happiness stats for a pet.
/// Stats trickle over time based on configurable rates.
/// Supports persistence for background stat updates.
@HiveType(typeId: 0)
class PetStats extends HiveObject {
  /// Hunger level: 0.0 (starving) to 1.0 (full)
  @HiveField(0)
  double _hunger;
  
  /// Happiness level: 0.0 (miserable) to 1.0 (ecstatic)
  @HiveField(1)
  double _happiness;
  
  /// Happiness buffer accumulated while app was in background and linked
  @HiveField(2)
  double _happinessBuffer;

  /// Rate at which hunger decreases per second (always active)
  @HiveField(3)
  double hungerDecayRate;
  
  /// Rate at which happiness increases per second (when device is synced)
  @HiveField(4)
  double happinessGainRate;
  
  /// Rate at which happiness decreases per second (when device is NOT synced)
  @HiveField(5)
  double happinessDecayRate;
  
  /// Timestamp of last update (for background calculations)
  @HiveField(6)
  DateTime _lastUpdateTime;
  
  /// Callback triggered when wellbeing drops below threshold
  void Function()? onLowWellbeing;
  
  /// Threshold for low wellbeing notification (0.0 to 1.0)
  @HiveField(7)
  double lowWellbeingThreshold;
  
  /// Whether low wellbeing notification was already sent (resets when recovered)
  bool _lowWellbeingNotified = false;

  // Save lock — ensures concurrent saveToPrefs() calls are serialised.
  Future<void> _saveLock = Future.value();
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Fail-safe to prevent overwriting SharedPreferences if load fails
  bool _canSave = false;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Gold coins (for clothing)
  @HiveField(8)
  int _goldCoins = 0;
  
  /// Silver coins (for food)
  @HiveField(9)
  int _silverCoins = 0;

  /// IDs of unlocked clothing items
  @HiveField(10)
  List<String> _unlockedClothingIds = [];

  /// Map of slot name to clothing ID for equipped items
  @HiveField(11)
  Map<String, String> _equippedClothing = {};

  PetStats({
    double hunger = 1.0,
    double happiness = 1.0,
    double happinessBuffer = 0.0,
    int goldCoins = 0,
    int silverCoins = 0,
    List<String>? unlockedClothingIds,
    Map<String, String>? equippedClothing,
    this.hungerDecayRate = 0.0000463,  // 6 hours to deplete
    this.happinessGainRate = 0.0001389, // 2 hours to fill
    this.happinessDecayRate = 0.0000463, // 6 hours to deplete
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

  /// Timestamp of last update
  DateTime get lastUpdateTime => _lastUpdateTime;

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

    // Happiness changes based on sync status AND hunger level
    // If hunger is critical (< 25%), happiness decays even if synced
    if (isDeviceSynced && _hunger >= 0.25) {
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
    save();
  }

  /// Reset stats to full
  void reset() {
    _hunger = 1.0;
    _happiness = 1.0;
    _happinessBuffer = 0.0;
    _lastUpdateTime = DateTime.now();
    _canSave = true; // Safe to save now
    save();
  }

  // ============ MONEY METHODS ============

  /// Add gold coins
  void addGold(int amount) {
    if (amount > 0) {
      _goldCoins += amount;
      save();
    }
  }

  /// Spend gold coins. Returns true if successful.
  bool spendGold(int amount) {
    if (amount > 0 && _goldCoins >= amount) {
      _goldCoins -= amount;
      save();
      return true;
    }
    return false;
  }

  /// Add silver coins
  void addSilver(int amount) {
    if (amount > 0) {
      _silverCoins += amount;
      save();
    }
  }

  /// Spend silver coins. Returns true if successful.
  bool spendSilver(int amount) {
    if (amount > 0 && _silverCoins >= amount) {
      _silverCoins -= amount;
      save();
      return true;
    }
    return false;
  }

  // ============ CLOTHING METHODS ============

  /// Unlock a clothing item
  void unlockClothing(String id) {
    if (!_unlockedClothingIds.contains(id)) {
      _unlockedClothingIds.add(id);
      save();
    }
  }

  /// Check if clothing is unlocked
  bool isClothingUnlocked(String id) => _unlockedClothingIds.contains(id);

  /// Equip clothing item (replaces existing item in same slot)
  void equipClothing(String slotName, String id) {
    _equippedClothing[slotName] = id;
    save();
  }

  /// Unequip clothing from slot
  void unequipClothing(String slotName) {
    _equippedClothing.remove(slotName);
    save();
  }


  /// Apply rewards from a completed mission
  void applyMissionReward(int gold, double happiness) {
    addGold(gold);
    _happiness = (_happiness + happiness).clamp(0.0, 1.0);
    save();
  }

  // ============ INVENTORY METHODS ============

  /// Map of food item ID to quantity owned
  @HiveField(12)
  Map<String, int> _foodInventory = {};

  /// Get current food inventory
  Map<String, int> get foodInventory => Map.unmodifiable(_foodInventory);

  /// Add food to inventory
  void addFood(String id, int quantity) {
    if (quantity > 0) {
      _foodInventory[id] = (_foodInventory[id] ?? 0) + quantity;
      save();
    }
  }

  /// Remove food from inventory. Returns true if successful.
  bool removeFood(String id, {int quantity = 1}) {
    final current = _foodInventory[id] ?? 0;
    if (current >= quantity) {
      _foodInventory[id] = current - quantity;
      if (_foodInventory[id] == 0) {
        _foodInventory.remove(id);
      }
      save();
      return true;
    }
    return false;
  }

  /// Get quantity of specific food item
  int getFoodQuantity(String id) => _foodInventory[id] ?? 0;

  // ============ PERSISTENCE ============

  // Single SharedPreferences key for the entire stats snapshot.
  // One atomic write is far less likely to be torn by a mid-save process kill
  // than 13 individual sequential writes.
  static const String _bundleKey = 'pet_stats_bundle';


  /// Restore state from a decoded JSON map. Returns true if a saved
  /// timestamp was found (needed to decide whether to apply background updates).
  bool _fromJson(Map<String, dynamic> json) {
    _hunger = (json['hunger'] as num?)?.toDouble() ?? _hunger;
    _happiness = (json['happiness'] as num?)?.toDouble() ?? _happiness;
    _happinessBuffer = (json['happinessBuffer'] as num?)?.toDouble() ?? 0.0;
    _goldCoins = (json['goldCoins'] as int?) ?? 0;
    _silverCoins = (json['silverCoins'] as int?) ?? 0;
    _unlockedClothingIds =
        List<String>.from(json['unlockedClothing'] as List? ?? []);
    _equippedClothing =
        Map<String, String>.from(json['equippedClothing'] as Map? ?? {});
    final inv = json['foodInventory'] as Map?;
    _foodInventory = inv != null
        ? inv.map((k, v) => MapEntry(k as String, (v as num).toInt()))
        : {};
    hungerDecayRate =
        (json['hungerDecayRate'] as num?)?.toDouble() ?? hungerDecayRate;
    happinessGainRate =
        (json['happinessGainRate'] as num?)?.toDouble() ?? happinessGainRate;
    happinessDecayRate =
        (json['happinessDecayRate'] as num?)?.toDouble() ?? happinessDecayRate;
    lowWellbeingThreshold =
        (json['lowWellbeingThreshold'] as num?)?.toDouble() ??
            lowWellbeingThreshold;
    final lastMs = json['lastUpdateMs'] as int?;
    if (lastMs != null) {
      _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      return true;
    }
    return false;
  }

  /// Read individual legacy SharedPreferences keys written before the bundle
  /// format was introduced. Returns true if a saved timestamp was found.
  bool _loadLegacyKeys(SharedPreferences prefs) {
    _hunger = prefs.getDouble('pet_hunger') ?? _hunger;
    _happiness = prefs.getDouble('pet_happiness') ?? _happiness;
    _happinessBuffer = prefs.getDouble('pet_happiness_buffer') ?? 0.0;
    _goldCoins = prefs.getInt('pet_gold_coins') ?? 0;
    _silverCoins = prefs.getInt('pet_silver_coins') ?? 0;
    _unlockedClothingIds =
        prefs.getStringList('pet_unlocked_clothing') ?? [];
    final equippedList = prefs.getStringList('pet_equipped_clothing') ?? [];
    _equippedClothing.clear();
    for (final entry in equippedList) {
      final parts = entry.split(':');
      if (parts.length == 2) _equippedClothing[parts[0]] = parts[1];
    }
    final inventoryList = prefs.getStringList('pet_food_inventory') ?? [];
    _foodInventory.clear();
    for (final entry in inventoryList) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final qty = int.tryParse(parts[1]);
        if (qty != null && qty > 0) _foodInventory[parts[0]] = qty;
      }
    }
    hungerDecayRate =
        prefs.getDouble('pet_hunger_decay_rate') ?? hungerDecayRate;
    happinessGainRate =
        prefs.getDouble('pet_happiness_gain_rate') ?? happinessGainRate;
    happinessDecayRate =
        prefs.getDouble('pet_happiness_decay_rate') ?? happinessDecayRate;
    lowWellbeingThreshold =
        prefs.getDouble('pet_low_wellbeing_threshold') ?? lowWellbeingThreshold;
    final lastMs = prefs.getInt('pet_last_update');
    if (lastMs != null) {
      _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      return true;
    }
    return false;
  }

  /// Enqueue a save. Concurrent callers are serialised — each waits for the
  /// previous save to finish before starting its own write.
  Future<void> save() {
    if (!_isInitialized || !_canSave) return Future.value();
    _saveLock =
        _saveLock.catchError((_) {}).then((_) => _doSave());
    return _saveLock;
  }

  Future<void> _doSave() async {
    final now = DateTime.now();
    _lastUpdateTime = now;
    
    debugPrint('[PetStats] SAVE START (Hive)');
    
    try {
      if (isInBox) {
        await super.save();
        debugPrint('[PetStats] SAVE SUCCESS (Hive) - Timestamp: $now');
        
        // Task 1: Mirror to SharedPreferences for native background service
        await _mirrorToPrefs();
      } else {
        debugPrint('[PetStats] SAVE FAILED - Not in a Hive box!');
        // Even if not in box (e.g. initial setup), we might want to mirror
        await _mirrorToPrefs();
      }
    } catch (e) {
      debugPrint('[PetStats] SAVE ERROR: $e');
    }
  }

  /// Mirror critical stats to SharedPreferences for the native background service.
  /// This ensures the service has access to the latest Hive data.
  Future<void> _mirrorToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Native Kotlin service expects these keys
      await prefs.setDouble('pet_hunger', _hunger);
      await prefs.setDouble('pet_happiness', _happiness);
      await prefs.setInt('pet_last_update', _lastUpdateTime.millisecondsSinceEpoch);
      await prefs.setDouble('pet_low_wellbeing_threshold', lowWellbeingThreshold);
      
      // Also mirror decay rates if they've changed
      await prefs.setDouble('pet_hunger_decay_rate', hungerDecayRate);
      await prefs.setDouble('pet_happiness_decay_rate', happinessDecayRate);
      await prefs.setDouble('pet_happiness_gain_rate', happinessGainRate);
      
      debugPrint('[PetStats] Mirror to SharedPreferences SUCCESS');
    } catch (e) {
      debugPrint('[PetStats] Mirror to SharedPreferences FAILED: $e');
    }
  }

  /// Load state from SharedPreferences and apply background updates.
  /// Reads the atomic bundle key; falls back to legacy individual keys
  /// for users upgrading from an earlier version.
  Future<void> loadFromPrefs({required bool isDeviceSynced}) async {
    if (_isLoading) {
      debugPrint('[PetStats] LOAD SKIPPED - Already loading');
      return;
    }
    
    debugPrint('[PetStats] LOAD START - isDeviceSynced: $isDeviceSynced');
    _isLoading = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      bool hadSavedState = false;
      bool wasLegacy = false;

      final bundleJson = prefs.getString(_bundleKey);
      if (bundleJson != null) {
        try {
          hadSavedState = _fromJson(
              jsonDecode(bundleJson) as Map<String, dynamic>);
          _canSave = hadSavedState;
          debugPrint('[PetStats] LOAD - Found bundle data');
        } catch (e) {
          debugPrint('[PetStats] Bundle parse error — falling back to legacy keys: $e');
          hadSavedState = _loadLegacyKeys(prefs);
          wasLegacy = hadSavedState;
          _canSave = hadSavedState;
        }
      } else {
        // First launch after update: migrate from old individual keys.
        hadSavedState = _loadLegacyKeys(prefs);
        wasLegacy = hadSavedState;
        _canSave = hadSavedState;
        if (hadSavedState) debugPrint('[PetStats] LOAD - Found legacy data for migration');
      }

      if (hadSavedState) {
        applyBackgroundUpdates(wasDeviceSynced: isDeviceSynced);
        if (isDeviceSynced) applyHappinessBuffer();
      } else {
        debugPrint('[PetStats] LOAD - No saved state found, using defaults');
        _canSave = true; // Safe to save defaults for new user
      }
      
      _isInitialized = true;
      
      // ONLY commit to bundle if we actually migrated legacy data or changed something.
      // If we just loaded defaults for a new user, we don't need to force a save immediately
      // which might race with other initializations.
      if (wasLegacy) {
        debugPrint('[PetStats] LOAD - Committing migrated legacy data to bundle');
        await save();
      }
      
      debugPrint('[PetStats] LOAD COMPLETE - Hunger: ${_hunger.toStringAsFixed(2)}, Gold: $_goldCoins');
    } finally {
      _isLoading = false;
    }
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
    Map<String, int>? foodInventory,
    double? hungerDecayRate,
    double? happinessGainRate,
    double? happinessDecayRate,
  }) {
    final copy = PetStats(
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
    
    // Copy inventory
    if (foodInventory != null) {
      copy._foodInventory = Map.from(foodInventory);
    } else {
      copy._foodInventory = Map.from(_foodInventory);
    }
    
    return copy;
  }

  @override
  String toString() =>
      'PetStats(hunger: ${(_hunger * 100).toStringAsFixed(1)}%, '
      'happiness: ${(_happiness * 100).toStringAsFixed(1)}%, '
      'gold: $_goldCoins, silver: $_silverCoins)';
}
