import 'package:flutter/material.dart';
import '../../game/items/food_item.dart';
import 'food_menu.dart'; // For FoodMenuData

class FridgeWidget extends StatelessWidget {
  final Map<String, int> inventory;

  const FridgeWidget({
    super.key,
    required this.inventory,
  });

  @override
  Widget build(BuildContext context) {
    // Filter items that we actually have in inventory
    final ownedItems = FoodMenuData.items.where((item) => (inventory[item.id] ?? 0) > 0).toList();

    if (ownedItems.isEmpty) {
      return const SizedBox.shrink(); // Hide if empty
    }

    return Container(
      width: 80, // Fixed width for sidebar
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(width: 2, color: Colors.black),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Icon(Icons.kitchen, size: 32),
          ),
          Flexible(
            child: ListView.separated(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: ownedItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = ownedItems[index];
                final quantity = inventory[item.id] ?? 0;
                
                return Draggable<FoodItem>(
                  data: item,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Image.asset(
                      item.assetPath,
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.5,
                    child: _buildFoodItem(item, quantity),
                  ),
                  child: _buildFoodItem(item, quantity),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(FoodItem item, int quantity) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              item.assetPath,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(width: 1, color: Colors.white),
                ),
                child: Text(
                  '$quantity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
