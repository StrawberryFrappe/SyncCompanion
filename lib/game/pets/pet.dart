import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'body_type.dart';
import 'pet_stats.dart';

/// Abstract base class for all virtual pets.
/// Provides common functionality for stats management, rotation effects,
/// and defines the interface that all pets must implement.
abstract class Pet extends PositionComponent {
  /// Display name of the pet
  final String name;
  
  /// Body type determines clothing restrictions
  final BodyType bodyType;
  
  /// Stats (hunger, happiness) with trickling behavior
  final PetStats stats;
  
  /// Reference to check if device is synced (set by game)
  bool Function()? isDeviceSyncedCallback;

  Pet({
    required this.name,
    required this.bodyType,
    PetStats? stats,
    super.position,
    super.size,
    super.anchor = Anchor.center,
  }) : stats = stats ?? PetStats();

  /// Get the body type configuration for this pet
  BodyTypeConfig get bodyTypeConfig => BodyTypes.getConfig(bodyType);

  /// Check if this pet can equip a given clothing slot
  bool canEquip(ClothingSlot slot) => bodyTypeConfig.canEquip(slot);

  /// Rotation angle based on overall wellbeing.
  /// 0° when healthy (wellbeing = 1.0), 180° when critical (wellbeing = 0.0)
  double get rotationAngle {
    final wellbeing = stats.overallWellbeing;
    return (1.0 - wellbeing) * pi;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update stats based on sync status
    final isSynced = isDeviceSyncedCallback?.call() ?? false;
    stats.update(dt, isDeviceSynced: isSynced);
    
    // Apply rotation based on wellbeing
    // DISABLED: Sprite expressions now show wellbeing instead of rotation
    // angle = rotationAngle;
  }

  /// Subclasses must implement their own rendering
  @override
  void render(Canvas canvas);

  @override
  String toString() => 'Pet($name, $bodyType, $stats)';
}
