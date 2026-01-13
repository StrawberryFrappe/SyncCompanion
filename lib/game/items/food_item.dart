class FoodItem {
  final String id;
  final String name;
  final int cost; // Silver coins
  final double hungerRestore; // 0.0 to 1.0 (clamped addition)
  final double happinessBonus; // 0.0 to 1.0 (clamped addition)
  final String assetPath;

  const FoodItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.hungerRestore,
    required this.happinessBonus,
    required this.assetPath,
  });
}

class FoodMenu {
  static const List<FoodItem> items = [
    FoodItem(
      id: 'apple',
      name: 'Apple',
      cost: 10,
      hungerRestore: 0.1,
      happinessBonus: 0.05,
      assetPath: 'assets/images/food_apple.png',
    ),
    FoodItem(
      id: 'burger',
      name: 'Burger',
      cost: 50,
      hungerRestore: 0.4,
      happinessBonus: 0.1,
      assetPath: 'assets/images/food_burger.png',
    ),
    FoodItem(
      id: 'sushi',
      name: 'Sushi',
      cost: 80,
      hungerRestore: 0.2,
      happinessBonus: 0.3, // High happiness
      assetPath: 'assets/images/food_sushi.png',
    ),
    FoodItem(
      id: 'cake',
      name: 'Cake',
      cost: 40,
      hungerRestore: 0.15,
      happinessBonus: 0.25,
      assetPath: 'assets/images/food_cake.png',
    ),
    FoodItem(
      id: 'water',
      name: 'Water',
      cost: 5,
      hungerRestore: 0.05,
      happinessBonus: 0.0,
      assetPath: 'assets/images/food_water.png',
    ),
  ];
  
  static FoodItem? getById(String id) {
    try {
      return items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
