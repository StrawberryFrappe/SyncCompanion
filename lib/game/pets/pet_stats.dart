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

  PetStats({
    double hunger = 1.0,
    double happiness = 1.0,
    double happinessBuffer = 0.0,
    this.hungerDecayRate = 0.01,
    this.happinessGainRate = 0.02,
    this.happinessDecayRate = 0.01,
    DateTime? lastUpdateTime,
  })  : _hunger = hunger.clamp(0.0, 1.0),
        _happiness = happiness.clamp(0.0, 1.0),
        _happinessBuffer = happinessBuffer.clamp(0.0, 1.0),
        _lastUpdateTime = lastUpdateTime ?? DateTime.now();

  /// Current hunger value (0.0 to 1.0)
  double get hunger => _hunger;
  
  /// Current happiness value (0.0 to 1.0)
  double get happiness => _happiness;
  
  /// Current happiness buffer (accumulated while linked in background)
  double get happinessBuffer => _happinessBuffer;

  /// Set hunger directly (clamped to 0.0-1.0)
  set hunger(double value) => _hunger = value.clamp(0.0, 1.0);
  
  /// Set happiness directly (clamped to 0.0-1.0)
  set happiness(double value) => _happiness = value.clamp(0.0, 1.0);

  /// Overall wellbeing: average of hunger and happiness (0.0 to 1.0)
  double get overallWellbeing => (_hunger + _happiness) / 2.0;

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
    
    // NOTE: Do NOT update _lastUpdateTime here!
    // It should only be updated when saving to prefs (for background time tracking)
  }

  /// Calculate and apply stats changes that occurred while app was in background.
  /// Call this when app returns to foreground.
  /// [wasDeviceSynced] indicates if the device was linked during background time.
  void applyBackgroundUpdates({required bool wasDeviceSynced}) {
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;
    
    print('[PetStats] applyBackgroundUpdates: elapsedSeconds=$elapsedSeconds, hungerDecayRate=$hungerDecayRate');
    print('[PetStats] Before: hunger=$_hunger, happiness=$_happiness');
    
    if (elapsedSeconds <= 0) {
      print('[PetStats] Skipping - elapsed time is <= 0');
      return;
    }
    
    final hungerDelta = hungerDecayRate * elapsedSeconds;
    final happinessDelta = happinessDecayRate * elapsedSeconds;
    
    // Hunger always decreases while in background
    _hunger = max(0.0, _hunger - hungerDelta);
    
    // Happiness decreases while in background (even if synced)
    _happiness = max(0.0, _happiness - happinessDelta);
    
    // If linked, the happiness buffer was accumulating
    if (wasDeviceSynced) {
      _happinessBuffer = min(1.0, _happinessBuffer + (happinessGainRate * elapsedSeconds));
    }
    
    print('[PetStats] After: hunger=$_hunger (delta=$hungerDelta), happiness=$_happiness (delta=$happinessDelta)');
    
    _lastUpdateTime = now;
  }

  /// Apply the accumulated happiness buffer to the happiness stat.
  /// Call this after applyBackgroundUpdates to "pump up" happiness.
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

  /// Save current state to SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update the timestamp to "now" - this marks when we saved, for background time tracking
    _lastUpdateTime = DateTime.now();
    
    print('[PetStats] saveToPrefs: hunger=$_hunger, happiness=$_happiness, lastUpdate=$_lastUpdateTime');
    await prefs.setDouble('pet_hunger', _hunger);
    await prefs.setDouble('pet_happiness', _happiness);
    await prefs.setDouble('pet_happiness_buffer', _happinessBuffer);
    await prefs.setInt('pet_last_update', _lastUpdateTime.millisecondsSinceEpoch);
  }

  /// Load state from SharedPreferences and apply background updates
  Future<void> loadFromPrefs({required bool isDeviceSynced}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load saved values (default to current if not saved)
    _hunger = prefs.getDouble('pet_hunger') ?? _hunger;
    _happiness = prefs.getDouble('pet_happiness') ?? _happiness;
    _happinessBuffer = prefs.getDouble('pet_happiness_buffer') ?? 0.0;
    
    final lastUpdateMs = prefs.getInt('pet_last_update');
    print('[PetStats] loadFromPrefs: hunger=$_hunger, happiness=$_happiness, lastUpdateMs=$lastUpdateMs, now=${DateTime.now().millisecondsSinceEpoch}');
    
    if (lastUpdateMs != null) {
      _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
      
      // Apply background updates based on time elapsed
      applyBackgroundUpdates(wasDeviceSynced: isDeviceSynced);
      
      // Apply happiness buffer if device was synced
      if (isDeviceSynced) {
        applyHappinessBuffer();
      }
    }
    
    // Save updated state
    await saveToPrefs();
  }

  /// Create a copy with modified rates
  PetStats copyWith({
    double? hunger,
    double? happiness,
    double? happinessBuffer,
    double? hungerDecayRate,
    double? happinessGainRate,
    double? happinessDecayRate,
  }) {
    return PetStats(
      hunger: hunger ?? _hunger,
      happiness: happiness ?? _happiness,
      happinessBuffer: happinessBuffer ?? _happinessBuffer,
      hungerDecayRate: hungerDecayRate ?? this.hungerDecayRate,
      happinessGainRate: happinessGainRate ?? this.happinessGainRate,
      happinessDecayRate: happinessDecayRate ?? this.happinessDecayRate,
    );
  }

  @override
  String toString() =>
      'PetStats(hunger: ${(_hunger * 100).toStringAsFixed(1)}%, '
      'happiness: ${(_happiness * 100).toStringAsFixed(1)}%, '
      'buffer: ${(_happinessBuffer * 100).toStringAsFixed(1)}%)';
}
