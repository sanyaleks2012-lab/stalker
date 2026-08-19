import 'package:detool64/logic/item_database.dart';

enum EquipmentType { weapon, ranged, magic, armor, helm }

extension EquipmentTypeExtension on EquipmentType {
  static EquipmentType? fromId(String equipmentId) {
    final overrideType = ItemDatabase.getOverrideType(equipmentId);
    if (overrideType != null) {
      return overrideType;
    }
    if (equipmentId.contains("WEAPON")) {
      return EquipmentType.weapon;
    } else if (equipmentId.contains("RANGED")) {
      return EquipmentType.ranged;
    } else if (equipmentId.contains("MAGIC")) {
      return EquipmentType.magic;
    } else if (equipmentId.contains("ARMOR") || equipmentId.contains("BODY")) {
      return EquipmentType.armor;
    } else if (equipmentId.contains("HELM") || equipmentId.contains("HEAD")) {
      return EquipmentType.helm;
    } else {
      return null;
    }
  }

  String get slot {
    switch (this) {
      case EquipmentType.weapon:
        return "Weapon";
      case EquipmentType.ranged:
        return "Ranged";
      case EquipmentType.magic:
        return "Magic";
      case EquipmentType.armor:
        return "Armor";
      case EquipmentType.helm:
        return "Helm";
    }
  }

  String get display => slot;
}
