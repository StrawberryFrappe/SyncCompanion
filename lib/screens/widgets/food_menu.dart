import 'package:flutter/material.dart';
import '../../game/items/food_item.dart';

class FoodStore extends StatelessWidget {
  final int currentSilver;
  final Function(FoodItem) onBuy;

  const FoodStore({
    super.key,
    required this.currentSilver,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      // Increased insetPadding to make dialog smaller (popup style)
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
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
                const Expanded(
                  child: Text(
                    'FOOD STORE',
                    style: TextStyle(
                      fontFamily: 'Monocraft',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(width: 1, color: Colors.black),
                  ),
                  child: Text(
                    '$currentSilver Silver',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(thickness: 2, color: Colors.black),
            const SizedBox(height: 12),
            
            // Grid of food items
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: FoodMenuData.items.length,
                itemBuilder: (context, index) {
                  final item = FoodMenuData.items[index];
                  final canAfford = currentSilver >= item.cost;
                  
                  return Opacity(
                    opacity: canAfford ? 1.0 : 0.7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(width: 2, color: Colors.black),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            item.assetPath,
                            width: 64,
                            height: 64,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canAfford ? Colors.green.shade100 : Colors.grey.shade300,
                              foregroundColor: Colors.black,
                              side: const BorderSide(width: 1, color: Colors.black),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: canAfford 
                                ? () {
                                    onBuy(item);
                                  } 
                                : null,
                            child: Text('Buy ${item.cost} S'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Re-export static data wrapper to avoid naming conflict with widget
class FoodMenuData {
  static const items = [
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
      happinessBonus: 0.3,
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
}
