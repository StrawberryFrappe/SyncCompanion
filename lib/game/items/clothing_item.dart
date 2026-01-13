import '../pets/body_type.dart';

class ClothingItem {
  final String id;
  final String name;
  final int cost; // Gold coins
  final ClothingSlot slot;
  final String assetPath;
  final double happinessBonus; // Passive bonus when equipped (optional)

  const ClothingItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.slot,
    required this.assetPath,
    this.happinessBonus = 0.0,
  });
}

class ClothingCatalog {
  static const List<ClothingItem> items = [
    ClothingItem(
      id: 'hat_basic',
      name: 'Fancy Hat',
      cost: 50,
      slot: ClothingSlot.head,
      assetPath: 'assets/images/clothing_hat_basic.png',
      happinessBonus: 0.0,
    ),
    ClothingItem(
      id: 'hat_winter',
      name: 'Winter Earmuffs',
      cost: 150,
      slot: ClothingSlot.head, // Or accessory? Bob is a ball, head works best.
      assetPath: 'assets/images/clothing_hat_winter.png',
      happinessBonus: 0.05,
    ),
    ClothingItem(
      id: 'hat_spring',
      name: 'Flower Crown',
      cost: 120,
      slot: ClothingSlot.head,
      assetPath: 'assets/images/clothing_hat_spring.png',
      happinessBonus: 0.1, // Flowers make people happy
    ),
    ClothingItem(
      id: 'hat_summer',
      name: 'Cool Shades',
      cost: 200,
      slot: ClothingSlot.head, // Technically eyes/face, but head slot for simplicity on a blob
      assetPath: 'assets/images/clothing_hat_summer.png',
      happinessBonus: 0.05,
    ),
    ClothingItem(
      id: 'hat_autumn',
      name: 'Leaf Beret',
      cost: 100,
      slot: ClothingSlot.head,
      assetPath: 'assets/images/clothing_hat_autumn.png',
      happinessBonus: 0.05,
    ),
  ];
  
  static ClothingItem? getById(String id) {
    try {
      return items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
