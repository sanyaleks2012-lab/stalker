// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:detool64/logic/equipment_type.dart';
import 'package:detool64/logic/item_database.dart';
import 'package:detool64/pages/equipment_manager.dart';
import 'package:detool64/pages/inventory_view/inventory_view.dart';
import 'package:detool64/logic/records_manager.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  @override
  void initState() {
    super.initState();
  }

  Row generateCheckbox(
      String name, bool value, void Function(bool?) onChanged) {
    return Row(
      children: [
        Text(name),
        const SizedBox(
          width: 50,
        ),
        Checkbox(value: value, onChanged: onChanged)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gridItems = [
      (
        "Weapon",
        "assets/images/katana.png",
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const InventoryView(EquipmentType.weapon),
            ),
          );
        }
      ),
      (
        "Ranged",
        "assets/images/shuriken.png",
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const InventoryView(EquipmentType.ranged),
            ),
          );
        }
      ),
      (
        "Magic",
        "assets/images/amulet.png",
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const InventoryView(EquipmentType.magic),
            ),
          );
        }
      ),
      (
        "Armor",
        "assets/images/armor.png",
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const InventoryView(EquipmentType.armor),
            ),
          );
        }
      ),
      (
        "Helm",
        "assets/images/helm.png",
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const InventoryView(EquipmentType.helm),
            ),
          );
        }
      ),
      (
        "Equipment Manager",
        "assets/images/weapons.png",
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EquipmentManager(
                existingEquipment: ItemDatabase.getAllEquipment(),
                ownedEquipment: RecordsManager.activeRecord!.equipment.values
                    .expand((e) => e)
                    .toList(),
              ),
            ),
          );
        }
      ),
    ];
    return Scaffold(
      body: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.80, // Уменьшили значение, чтобы дать больше высоты под текст
        ),
        itemCount: gridItems.length,
        itemBuilder: (context, index) {
          final (label, imagePath, onTap) = gridItems[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceTint
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.all(8), // Уменьшили с 12 до 8
                    shape: const ContinuousRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                  ),
                  onPressed: onTap,
                  child: Image.asset(imagePath, width: 64, height: 64), // Уменьшили с 64 до 56
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15, // Уменьшили с 16 до 13 для хорошей читаемости
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
   } // Закрывает метод build
}  
