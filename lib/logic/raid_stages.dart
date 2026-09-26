import 'dart:io';
import 'package:xml/xml.dart';
import 'package:saturn/shizuku_file.dart';
import 'package:saturn/shizuku_api.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:saturn/logic/record.dart';
import 'package:saturn/main.dart';
import 'package:xml/xpath.dart';

class RaidStagesManager {
  static const userdataPath =
      "/sdcard/Android/data/com.sf2.de/files/mod/userdata";
  static const raidStagesFilePath =
      "$userdataPath/raid_stages_default.xml";

  static XmlDocument? xmlDocument;
  static XmlElement? root;

  static Future<XmlDocument> loadRaidStagesXml() async {
    try {
      // Ensure directory exists
      final directory = Directory(userdataPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Check if file exists
      final file = File(raidStagesFilePath);
      if (!await file.exists()) {
        // Create default file if it doesn't exist
        await _createDefaultRaidStagesFile();
      }

      // Read file content
      final content = await readFile(raidStagesFilePath);
      final xmlDocument = XmlDocument.parse(content);
      
      RaidStagesManager.xmlDocument = xmlDocument;
      RaidStagesManager.root = xmlDocument.findAllElements("Root").first;
      
      return xmlDocument;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _createDefaultRaidStagesFile() async {
    final defaultXml = '''<?xml version="1.0" encoding="utf-8"?>
<Root>
  <Zones>
  </Zones>
</Root>''';
    
    await writeFile(raidStagesFilePath, defaultXml);
  }

  static Future<void> saveRaidStagesXml() async {
    if (xmlDocument == null) return;
    
    try {
      final formattedXml = xmlDocument!.toXmlString(pretty: true);
      await writeFile(raidStagesFilePath, formattedXml);
      Fluttertoast.showToast(msg: "Raid stages saved successfully");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error saving raid stages: $e");
      rethrow;
    }
  }

  static List<XmlElement> getZones() {
    if (root == null) return [];
    final zonesNode = root!.findAllElements("Zones").firstOrNull;
    if (zonesNode == null) return [];
    return zonesNode.findAllElements("Zone").toList();
  }

  static XmlElement? createZone({required String name, required String fileName}) {
    if (root == null) return null;
    
    final zonesNode = root!.findAllElements("Zones").firstOrNull;
    if (zonesNode == null) {
      zonesNode = XmlElement(XmlName("Zones"), []);
      root!.children.add(zonesNode);
    }
    
    final zone = XmlElement(
      XmlName("Zone"),
      [],
      [
        XmlAttribute(XmlName("Name"), name),
        XmlAttribute(XmlName("FileName"), fileName),
      ]
    );
    
    zonesNode.children.add(zone);
    return zone;
  }

  static bool deleteZone(XmlElement zone) {
    if (root == null) return false;
    
    final zonesNode = root!.findAllElements("Zones").firstOrNull;
    if (zonesNode == null) return false;
    
    zonesNode.children.remove(zone);
    return true;
  }

  static List<XmlElement> getBattles(XmlElement zone) {
    return zone.findAllElements("Battle").toList();
  }

  static XmlElement? createBattle(XmlElement zone, {String name = "NEW_BOSS", String title = "New Boss"}) {
    final battle = XmlElement(
      XmlName("Battle"),
      [],
      [
        XmlAttribute(XmlName("Name"), name),
        XmlAttribute(XmlName("Title"), title),
        XmlAttribute(XmlName("Type"), "FINAL_BATTLE"),
      ]
    );
    
    // Add basic Warrior element
    final warrior = XmlElement(
      XmlName("Warrior"),
      [],
      [
        XmlAttribute(XmlName("Template"), ""),
        XmlAttribute(XmlName("Tactic"), ""),
        XmlAttribute(XmlName("WarriorPower"), "100"),
        XmlAttribute(XmlName("ShieldTotal"), "0"),
      ]
    );
    battle.children.add(warrior);
    
    // Add basic Fight element
    final fight = XmlElement(
      XmlName("Fight"),
      [],
      [
        XmlAttribute(XmlName("Rounds"), "1"),
        XmlAttribute(XmlName("RoundTime"), "60"),
      ]
    );
    battle.children.add(fight);
    
    // Add Rules container
    final rules = XmlElement(XmlName("Rules"), [], []);
    battle.children.add(rules);
    
    zone.children.add(battle);
    return battle;
  }

  static bool deleteBattle(XmlElement battle) {
    // Find parent zone
    final parent = battle.parent;
    if (parent == null || !(parent is XmlElement)) return false;
    
    parent.children.remove(battle);
    return true;
  }

  static List<XmlElement> getWarriorPerks(XmlElement warrior) {
    final perksNode = warrior.findAllElements("Perks").firstOrNull;
    if (perksNode == null) return [];
    return perksNode.findAllElements("Perk").toList();
  }

  static XmlElement? addWarriorPerk(XmlElement warrior, {required String perkName, Map<String, String> attributes = const {}}) {
    // Find or create Perks node
    var perksNode = warrior.findAllElements("Perks").firstOrNull;
    if (perksNode == null) {
      perksNode = XmlElement(XmlName("Perks"), [], []);
      warrior.children.add(perksNode);
    }
    
    final perk = XmlElement(
      XmlName("Perk"),
      [],
      [
        XmlAttribute(XmlName("Name"), perkName),
      ]
    );
    
    // Add Set element if attributes provided
    if (attributes.isNotEmpty) {
      final setElement = XmlElement(
        XmlName("Set"),
        [],
        attributes.entries.map((e) => XmlAttribute(XmlName(e.key), e.value)).toList()
      );
      perk.children.add(setElement);
    }
    
    perksNode.children.add(perk);
    return perk;
  }

  static Map<String, dynamic> getPresetPerks() {
    return {
      "1": ("OVERHEAT", "PERK_ITEM_SPECIAL_OVERHEAT_WEAPON", {"Aspect": "100000", "Frames": "300"}),
      "2": ("BLEEDING", "PERK_ITEM_SPECIAL_BLEEDING_WEAPON", {"Aspect": "100000"}),
      "3": ("DAMAGE ABSORPTION", "PERK_ITEM_SPECIAL_DAMAGE_ABSORBPTION_BODY_ARMOR", {"Aspect": "100000", "Chance": "0.2"}),
      "4": ("INVISIBILITY", "PERK_INVISIBILITY", {"Frames": "600"}),
      "5": ("BLOCK BREAKER", "PERK_BLOCK_BREAKER", {"Chance": "0.33"}),
      "6": ("PAIN RAGE", "PERK_PAIN_RAGE", {"Chance": "0.25", "DamageFactor": "3000"}),
      "7": ("PLOT TWIST", "PERK_PLOT_TWIST", {"Chance": "1.0", "Type": "CopyMagic"}),
      "8": ("SOUL TYPHOON", "PERK_SOUL_TYPHOON", {"Aspect": "100000"}),
      "9": ("TIME SHIFT", "PERK_TIME_SHIFT", {"Frames": "300"}),
      "10": ("CRIMSON CORRUPTION", "PERK_CRIMSON_CORRUPTION", {"Aspect": "100000"}),
      "11": ("ROARING LIGHT", "PERK_ROARING_LIGHT", {"Aspect": "100000"}),
    };
  }

  static Map<String, dynamic> getPresetRules() {
    return {
      "1": ("HOT GROUND", "HOT_GROUND", "HotGround", {"Frames": "720", "ApplyTo": "Player"}),
      "2": ("INVERTED JOYSTICK", "INVERTED_JOYSTICK", "InvertJoystick", {}),
      "3": ("NO HEALTH BAR", "NO_HEALTHBAR", "NoHealthBar", {}),
      "4": ("NO JUMPS", "NO_JUMPS", "NoAnimation", {"Name": "Jump"}),
      "5": ("NO KICKS", "NO_KICKS", "NoButton", {"Name": "Kick", "ApplyTo": "Player"}),
      "6": ("NO BLOCKS", "NO_BLOCKS", "RemoveInterval", {"Type": "Block", "ApplyTo": "Player"}),
    };
  }
}