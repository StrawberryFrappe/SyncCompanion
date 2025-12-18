import 'package:flutter/material.dart';
import '../../game/items/clothing_item.dart';
import '../../game/pets/pet_stats.dart';

class WardrobeMenuWidget extends StatefulWidget {
  final PetStats stats;
  final Function(ClothingItem) onBuy;
  final Function(ClothingItem) onEquip;
  final Function(ClothingItem) onUnequip;

  const WardrobeMenuWidget({
    super.key,
    required this.stats,
    required this.onBuy,
    required this.onEquip,
    required this.onUnequip,
  });

  @override
  State<WardrobeMenuWidget> createState() => _WardrobeMenuWidgetState();
}

class _WardrobeMenuWidgetState extends State<WardrobeMenuWidget> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      // Remove insetPadding to allow centering of small constraints
      insetPadding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
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
                    'WARDROBE',
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
                    color: Colors.amber.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(width: 1, color: Colors.black),
                  ),
                  child: Text(
                    '${widget.stats.goldCoins} GOLD',
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
            
            // Grid of clothing items
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: ClothingCatalog.items.length,
                itemBuilder: (context, index) {
                  final item = ClothingCatalog.items[index];
                  final isUnlocked = widget.stats.isClothingUnlocked(item.id);
                  final isEquipped = widget.stats.equippedClothing[item.slot.name] == item.id;
                  final canAfford = widget.stats.goldCoins >= item.cost;
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: isEquipped ? Colors.green.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        width: isEquipped ? 3 : 2,
                        color: isEquipped ? Colors.green : Colors.black,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Item View - Fixed Size 64x64
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Image.asset(
                            item.assetPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (c, e, s) => Opacity(
                              opacity: 0.5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.checkroom, size: 32, color: Colors.grey),
                                  const SizedBox(height: 4),
                                  Text('Missing', style: TextStyle(fontSize: 8, color: Colors.red)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          item.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Action Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: _buildActionButton(item, isUnlocked, isEquipped, canAfford),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildActionButton(ClothingItem item, bool isUnlocked, bool isEquipped, bool canAfford) {
    if (isUnlocked) {
      if (isEquipped) {
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade100,
            foregroundColor: Colors.red.shade900,
            padding: EdgeInsets.zero,
            side: const BorderSide(color: Colors.red),
          ),
          onPressed: () {
             widget.onUnequip(item);
             setState(() {});
          },
          child: const Text('UNEQUIP', style: TextStyle(fontSize: 10)),
        );
      } else {
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade100,
            foregroundColor: Colors.green.shade900,
            padding: EdgeInsets.zero,
            side: const BorderSide(color: Colors.green),
          ),
          onPressed: () {
            widget.onEquip(item);
            setState(() {});
          },
          child: const Text('EQUIP', style: TextStyle(fontSize: 10)),
        );
      }
    } else {
      // Locked - Buy button
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canAfford ? Colors.amber.shade200 : Colors.grey.shade300,
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Colors.black),
        ),
        onPressed: canAfford 
            ? () {
                widget.onBuy(item);
                setState(() {});
              } 
            : null,
        child: Text('${item.cost} G', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
  }
}
