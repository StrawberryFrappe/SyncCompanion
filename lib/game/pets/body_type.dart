/// Body types define the physical form of a pet and determine
/// which clothing slots are available for customization.

enum BodyType {
  /// Ball-shaped pets (like Bob the Blob) - only head accessories
  ball,
  
  /// Humanoid pets - can wear all clothing types
  humanoid,
  
  /// Four-legged pets - no feet accessories
  quadruped,
}

/// Available slots for clothing/accessories
enum ClothingSlot {
  head,      // Hats, glasses, etc.
  body,      // Shirts, jackets, etc.
  feet,      // Shoes, socks, etc.
  accessory, // Misc items (necklaces, etc.)
}

/// Configuration for a body type's allowed clothing slots
class BodyTypeConfig {
  final BodyType type;
  final Set<ClothingSlot> allowedSlots;
  final String description;

  const BodyTypeConfig({
    required this.type,
    required this.allowedSlots,
    required this.description,
  });

  bool canEquip(ClothingSlot slot) => allowedSlots.contains(slot);
}

/// Predefined configurations for each body type
class BodyTypes {
  static const ball = BodyTypeConfig(
    type: BodyType.ball,
    allowedSlots: {ClothingSlot.head, ClothingSlot.accessory},
    description: 'Round blob-like body. Can only wear hats and accessories.',
  );

  static const humanoid = BodyTypeConfig(
    type: BodyType.humanoid,
    allowedSlots: {ClothingSlot.head, ClothingSlot.body, ClothingSlot.feet, ClothingSlot.accessory},
    description: 'Human-like body. Can wear all clothing types.',
  );

  static const quadruped = BodyTypeConfig(
    type: BodyType.quadruped,
    allowedSlots: {ClothingSlot.head, ClothingSlot.body, ClothingSlot.accessory},
    description: 'Four-legged body. Cannot wear footwear.',
  );

  static BodyTypeConfig getConfig(BodyType type) {
    switch (type) {
      case BodyType.ball:
        return ball;
      case BodyType.humanoid:
        return humanoid;
      case BodyType.quadruped:
        return quadruped;
    }
  }
}
