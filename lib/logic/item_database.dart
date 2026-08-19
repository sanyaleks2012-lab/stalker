import 'package:flutter/services.dart';
import 'package:detool64/logic/enchantment.dart';
import 'package:detool64/logic/equipment_type.dart';
import 'package:toml/toml.dart';

class ItemTrait {
  final String display;
  final String id;
  final int color;

  @override
  bool operator ==(Object other) => other is ItemTrait && other.id == id;

  const ItemTrait(this.id, this.display, this.color);
}

class ItemDatabase {
  static var dictionary = {};
  static List<ItemTrait> traits = [];

  static Future<Iterable<ItemTrait>> loadTraits() async {
    final tomlContent = await rootBundle.loadString("assets/traits.toml");
    final tomlMap = TomlDocument.parse(tomlContent).toMap();
    return tomlMap.entries.map((e) =>
        ItemTrait(e.key, e.value["display"], int.parse(e.value["color"])));
  }

  static Future<void> load() async {
    for (final type in EquipmentType.values) {
      final tomlContent =
          await rootBundle.loadString("assets/item_database/${type.name}.toml");
      final tomlMap = TomlDocument.parse(tomlContent).toMap();
      dictionary.addAll(tomlMap);
    }
  }

  static String getName(String id) {
    var name = dictionary[id]?["name"];
    if (name == "") {
      name = id;
    }
    return name ?? id;
  }

  static String getDescription(String id) =>
      dictionary[id]?["description"] ?? "";

  static Iterable<ItemTrait> getTraits(String id) {
    List<String> itemTraits = (dictionary[id]?["traits"] ?? []).cast<String>();
    return itemTraits.map((e) => traits.where((t) => t.id == e).first);
  }

  static Iterable<String> getEquipmentByType(EquipmentType type) =>
      dictionary.entries
          .where((e) => EquipmentTypeExtension.fromId(e.key) == type)
          .map((e) => e.key);

  static Iterable<String> getAllEquipment() =>
      dictionary.entries.map((e) => e.key);

  static Iterable<Enchantment> getEnchantments(String id) {
    final enchantments =
        (dictionary[id]?["enchantments"] ?? []) as List<dynamic>;
    return enchantments.map((e) => EnchantmentsManager.findById(e)!);
  }

  static EquipmentType? getOverrideType(String id) {
    String? type = dictionary.entries
        .where((e) => e.key == id)
        .firstOrNull
        ?.value["override_type"];
    if (type == null) return null;
    return EquipmentType.values.firstWhere((e) => e.name == type);
  }
}
