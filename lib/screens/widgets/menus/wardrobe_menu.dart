import 'package:flutter/material.dart';
import 'package:Therapets/l10n/app_localizations.dart';
import '../../../game/items/clothing_item.dart';
import '../../../game/pets/pet_stats.dart';

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
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.wardrobe,
                    style: const TextStyle(
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
                    AppLocalizations.of(context)!.goldCurrency(widget.stats.goldCoins),
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
                                  Text(AppLocalizations.of(context)!.missingAsset, style: TextStyle(fontSize: 8, color: Colors.red)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          _localizedClothingName(context, item),
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
          child: Text(AppLocalizations.of(context)!.unequip, style: const TextStyle(fontSize: 10)),
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
          child: Text(AppLocalizations.of(context)!.equip, style: const TextStyle(fontSize: 10)),
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
        child: Text(AppLocalizations.of(context)!.costGold(item.cost), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
  }
}

String _localizedClothingName(BuildContext context, ClothingItem item) {
  final l10n = AppLocalizations.of(context)!;
  switch (item.id) {
    case 'hat_basic': return l10n.clothingFancyHat;
    case 'hat_winter': return l10n.clothingWinterEarmuffs;
    case 'hat_spring': return l10n.clothingFlowerCrown;
    case 'hat_summer': return l10n.clothingCoolShades;
    case 'hat_autumn': return l10n.clothingLeafBeret;
    default: return item.name;
  }
}
