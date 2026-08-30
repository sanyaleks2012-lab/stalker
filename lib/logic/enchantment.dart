import 'dart:io';
import 'package:flutter/services.dart';
import 'package:saturn/logic/equipment_type.dart';
import 'package:saturn/main.dart';
import 'package:toml/toml.dart';
import 'package:xml/xml.dart';

class EnchantmentGroup {
  final String id;
  final String displayName;
  final int color;
  final int order;
  final bool hasAspect;

  EnchantmentGroup(
      this.id, this.displayName, this.color, this.order, this.hasAspect);

  factory EnchantmentGroup.fromToml(Map<String, dynamic> tomlMap) {
    return EnchantmentGroup(
        tomlMap["id"],
        tomlMap["displayName"],
        int.parse(tomlMap["color"]),
        tomlMap["order"],
        tomlMap["hasAspect"] ?? true);
  }
}

class Enchantment {
  final String name;
  final String id;
  final String? description;
  final Map<EquipmentType, String> ids;
  final EnchantmentGroup group;

  const Enchantment(this.name, this.id, this.description, this.ids, this.group);

  factory Enchantment.fromToml(
      MapEntry<String, dynamic> entry, EnchantmentGroup group) {
    if (entry.value.containsKey("id")) {
      final id = entry.value["id"] as String;
      return Enchantment(
          entry.value["name"] as String,
          entry.key,
          entry.value["description"] as String?,
          {
            EquipmentType.weapon: id,
            EquipmentType.ranged: id,
            EquipmentType.magic: id,
            EquipmentType.armor: id,
            EquipmentType.helm: id,
          },
          group);
    } else {
      final equipmentIdsRaw =
          entry.value["equipment_ids"] as Map<String, dynamic>;
      final equipmentIds = equipmentIdsRaw.map(
        (k, v) => MapEntry(EquipmentType.values.byName(k), v as String),
      );

      return Enchantment(entry.value["name"] as String, entry.key,
          entry.value["description"] as String?, equipmentIds, group);
    }
  }

  String? idFor(EquipmentType type) => ids[type];
}

class EnchantmentsManager {
  static List<Enchantment> enchantments = [];
  static List<EnchantmentGroup> groups = [];

  static const String externalPerksPath = "/sdcard/AddNew/perk";

  static Future<void> loadFromFiles() async {
    enchantments.clear();
    groups.clear();

    final targetDir = Directory(externalPerksPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Проверяем наличие .toml файлов в /sdcard/AddNew/perk
    List<FileSystemEntity> tomlFiles = targetDir
        .listSync()
        .where((e) => e is File && e.path.endsWith('.toml'))
        .toList();

    // Если папка пуста — копируем из ассетов
    if (tomlFiles.isEmpty) {
      logger.i("Perk directory is empty. Copying defaults from assets...");
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assetPaths = manifest
          .listAssets()
          .where((key) => key.startsWith("assets/enchantments") && key.endsWith(".toml"))
          .toList();

      for (final assetPath in assetPaths) {
        final content = await rootBundle.loadString(assetPath);
        final fileName = assetPath.split('/').last;
        final newFile = File("${targetDir.path}/$fileName");
        await newFile.writeAsString(content);
      }

      tomlFiles = targetDir
          .listSync()
          .where((e) => e is File && e.path.endsWith('.toml'))
          .toList();
    }

    // Парсим все скопированные/существующие TOML файлы
    for (final file in tomlFiles.whereType<File>()) {
      try {
        final tomlString = await file.readAsString();
        final tomlMap = TomlDocument.parse(tomlString).toMap();
        final group = EnchantmentGroup.fromToml(tomlMap["group"]);
        tomlMap.remove("group");
        groups.add(group);
        enchantments.addAll(tomlMap.entries.map((e) {
          final data = e.value as Map<String, dynamic>;
          return Enchantment.fromToml(MapEntry(e.key, data), group);
        }));
      } catch (e) {
        logger.e("Error parsing perk file ${file.path}: $e");
      }
    }

    groups.sort((a, b) => a.order.compareTo(b.order));
  }

  static Enchantment? findByEquipmentTypeId(EquipmentType type, String id) {
    return enchantments.where((e) => e.idFor(type) == id).firstOrNull;
  }

  static Enchantment? findByAnyEquipmentTypeId(String id) {
    return enchantments.where((e) => e.ids.values.contains(id)).firstOrNull;
  }

  static Enchantment? findById(String id) {
    return enchantments.where((e) => e.id == id).firstOrNull;
  }
}

class AppliedEnchantment {
  final Enchantment enchantment;
  int? aspect;
  static const int maxAspect = 2001;

  AppliedEnchantment(this.enchantment, this.aspect);

  XmlElement toXml(EquipmentType type) {
    final id = enchantment.idFor(type);
    if (id == null) {
      throw ArgumentError('Enchantment not applicable to $type');
    }

    return XmlElement(
      XmlName("Perk"),
      [XmlAttribute(XmlName("Name"), id)],
      aspect == null
          ? []
          : [
              XmlElement(XmlName("Set"),
                  [XmlAttribute(XmlName("Aspect"), aspect.toString())])
            ],
    );
  }
}
