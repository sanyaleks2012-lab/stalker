import 'package:flutter/material.dart';
import 'package:saturn/logic/enchantment.dart';
import 'package:saturn/logic/equipment.dart';
import 'package:saturn/logic/equipment_type.dart';
import 'package:saturn/logic/item_database.dart';
import 'package:saturn/logic/records_manager.dart';
import 'package:saturn/pages/inventory_view/new_enchantment.dart';
import 'package:saturn/ui/split_filled_button.dart';

class EquipmentManager extends StatefulWidget {
  final Iterable<String> existingEquipment;
  final List<Equipment> ownedEquipment;

  const EquipmentManager(
      {super.key,
      required this.existingEquipment,
      required this.ownedEquipment});

  @override
  State<EquipmentManager> createState() => _EquipmentManagerState();
}

class TraitItem {
  bool enabled = false;
  final ItemTrait trait;

  TraitItem(this.trait) {
    enabled = enabledByDefault();
  }

  bool enabledByDefault() {
    return !["unobtainable", "defunct", "deceased", "set_dragon"]
        .contains(trait.id);
  }
}

class EquipmentItem {
  bool enabled = true;
  final EquipmentType type;

  EquipmentItem(this.type);
}

class _EquipmentManagerState extends State<EquipmentManager> {
  List<TraitItem> traits =
      ItemDatabase.traits.map((e) => TraitItem(e)).toList();
  List<EquipmentItem> equipmentTypes =
      EquipmentType.values.map((e) => EquipmentItem(e)).toList();
  bool selectAllTraits = false;
  bool equipmentWithoutTraits = true;
  int equipmentLevel = Equipment.maxLevel;
  int equipmentUpgrade = Equipment.maxUpgrade;
  bool shouldSaveRecord = true;
  String status = "";

  @override
  void initState() {
    super.initState();
    setState(() {
      equipmentLevel = RecordsManager.activeRecord!.level;
    });
  }

  void _openSkeletonEnchantmentEditor() {
    const String skeletonId = "skeleton";
    const EquipmentType skeletonType = EquipmentType.weapon;

    Equipment skeleton = widget.ownedEquipment.firstWhere(
      (e) => e.id == skeletonId,
      orElse: () {
        final newEquipment = Equipment(
          skeletonType,
          skeletonId,
          equipmentLevel,
          equipmentUpgrade,
        );
        RecordsManager.activeRecord!.equipment[skeletonType]?.add(newEquipment);
        widget.ownedEquipment.add(newEquipment);
        return newEquipment;
      },
    );

    showDialog(
      context: context,
      builder: (context) => NewEnchantmentDialog(
        enchantments: skeleton.enchantments.map((e) => e.enchantment).toList(),
        type: skeleton.type,
        equipmentId: skeleton.id,
        onPressed: (ench, count) {
          setState(() {
            for (int i = 0; i < count; i++) {
              skeleton.enchantments.add(
                AppliedEnchantment(
                  ench,
                  ench.group.hasAspect ? AppliedEnchantment.maxAspect : null,
                ),
              );
            }
          });

          if (shouldSaveRecord && RecordsManager.activeRecord != null) {
            RecordsManager.saveRecord(RecordsManager.activeRecord!).then((_) {
              setState(() {
                status = "Added $count x ${ench.name} to Skeleton";
              });
            });
          } else {
            setState(() {
              status = "Added $count x ${ench.name} to Skeleton";
            });
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                        value: selectAllTraits,
                        onChanged: (v) => {
                              setState(() {
                                selectAllTraits = v ?? false;
                                for (var e in traits) {
                                  e.enabled = v ?? false;
                                }
                              })
                            }),
                    const Text("Select All")
                  ],
                ),
                Row(
                  children: [
                    Switch(
                        value: equipmentWithoutTraits,
                        onChanged: (v) => {
                              setState(() {
                                equipmentWithoutTraits = v;
                              })
                            }),
                    const Flexible(child: Text("Equipment without traits"))
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemBuilder: (context, i) => Row(
                      children: [
                        Switch(
                            value: traits[i].enabled,
                            onChanged: (v) => {
                                  setState(() {
                                    traits[i].enabled = v;
                                  })
                                }),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(traits[i].trait.display,
                              softWrap: true, overflow: TextOverflow.visible),
                        ),
                      ],
                    ),
                    itemCount: traits.length,
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(
            width: 16,
            thickness: 2,
            color: Colors.grey,
            indent: 8,
            endIndent: 8,
          ),
          Expanded(
            child: Column(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  itemBuilder: (context, i) => Row(
                    children: [
                      Checkbox(
                          value: equipmentTypes[i].enabled,
                          onChanged: (v) {
                            setState(() {
                              equipmentTypes[i].enabled = v ?? false;
                            });
                          }),
                      Text(equipmentTypes[i].type.display)
                    ],
                  ),
                  itemCount: equipmentTypes.length,
                ),
                Text("Equipment level: $equipmentLevel"),
                Slider(
                    value: equipmentLevel.toDouble(),
                    onChanged: (v) =>
                        setState(() => equipmentLevel = v.toInt()),
                    min: Equipment.minLevel.toDouble(),
                    max: Equipment.maxLevel.toDouble(),
                    divisions: (Equipment.maxLevel - Equipment.minLevel) > 0
                        ? Equipment.maxLevel - Equipment.minLevel
                        : 1),
                Text("Upgrade level: $equipmentUpgrade"),
                Slider(
                    value: equipmentUpgrade.toDouble(),
                    onChanged: (v) =>
                        setState(() => equipmentUpgrade = v.toInt()),
                    min: Equipment.minUpgrade.toDouble(),
                    max: Equipment.maxUpgrade.toDouble(),
                    divisions: (Equipment.maxUpgrade - Equipment.minUpgrade) > 0
                        ? Equipment.maxUpgrade - Equipment.minUpgrade
                        : 1),
                Row(children: [
                  Checkbox(
                      value: shouldSaveRecord,
                      onChanged: (v) => setState(() {
                            shouldSaveRecord = v ?? false;
                          })),
                  const Text("Save changes")
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    children: [
                      SplitFilledButton(
                          onLeftPressed: () {
                            final enabledTraits =
                                traits.where((e) => e.enabled).map((e) => e.trait);
                            final equipmentToAdd = widget.existingEquipment
                                .where((e) => equipmentTypes
                                    .where((t) => t.enabled)
                                    .map((t) => t.type)
                                    .contains(EquipmentTypeExtension.fromId(e)!))
                                .where((e) {
                                  final itemTraits = ItemDatabase.getTraits(e);
                                  return itemTraits
                                          .any((t) => enabledTraits.contains(t)) ||
                                      equipmentWithoutTraits && itemTraits.isEmpty;
                                })
                                .toSet()
                                .difference(
                                    widget.ownedEquipment.map((e) => e.id).toSet());
                            for (var equipmentId in equipmentToAdd) {
                              final equipmentType =
                                  EquipmentTypeExtension.fromId(equipmentId)!;
                              final equipment = Equipment(equipmentType,
                                  equipmentId, equipmentLevel, equipmentUpgrade);
                              equipment.enchantments =
                                  ItemDatabase.getEnchantments(equipmentId)
                                      .map((ench) => AppliedEnchantment(
                                          ench,
                                          ench.group.hasAspect
                                              ? AppliedEnchantment.maxAspect
                                              : null))
                                      .toList();
                              RecordsManager.activeRecord!.equipment[equipmentType]!
                                  .add(equipment);
                              widget.ownedEquipment.add(equipment);
                            }
                            if (shouldSaveRecord) {
                              RecordsManager.saveRecord(
                                      RecordsManager.activeRecord!)
                                  .then((_) {
                                setState(() => status =
                                    "Added ${equipmentToAdd.length} items");
                              });
                            } else {
                              setState(() {
                                status = "Added ${equipmentToAdd.length} items";
                              });
                            }
                          },
                          onRightPressed: () {
                            final enabledTraits =
                                traits.where((e) => e.enabled).map((e) => e.trait);
                            final equipmentToRemove =
                                widget.ownedEquipment.where((e) {
                              var itemTraits = ItemDatabase.getTraits(e.id);
                              return itemTraits
                                      .any((t) => enabledTraits.contains(t)) ||
                                  equipmentWithoutTraits && itemTraits.isEmpty;
                            }).toList();
                            for (var equipment in equipmentToRemove) {
                              RecordsManager.activeRecord!.equipment[equipment.type]
                                  ?.remove(equipment);
                              widget.ownedEquipment.remove(equipment);
                            }
                            if (shouldSaveRecord) {
                              RecordsManager.saveRecord(
                                      RecordsManager.activeRecord!)
                                  .then((_) {
                                setState(() => status =
                                    "Removed ${equipmentToRemove.length} items");
                              });
                            } else {
                              setState(() {
                                status =
                                    "Removed ${equipmentToRemove.length} items";
                              });
                            }
                          },
                          leftChild: const Text("Add"),
                          rightChild: const Text("Remove")),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _openSkeletonEnchantmentEditor,
                        icon: const Icon(Icons.flash_on),
                        label: const Text("Enchant Skeleton"),
                      ),
                    ],
                  ),
                ),
                Text(status)
              ],
            ),
          )
        ],
      ),
    ));
  }
}
