<documents>
<document index="1">
<source>lib/app.dart</source>
<document_content>
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:saturn/repo.dart';
import 'package:saturn/pages/debug.dart';
import 'package:saturn/ui/app_bar.dart';
import 'package:saturn/logic/enchantment.dart';
import 'package:saturn/main.dart';
import 'package:saturn/pages/edit_xml/edit_xml.dart';
import 'package:saturn/pages/equipment.dart';
import 'package:saturn/pages/general.dart';
import 'package:saturn/pages/records/records.dart';
import 'package:saturn/logic/record.dart';
import 'package:saturn/logic/records_manager.dart';
import 'package:signals/signals.dart' as signals_core;
import 'package:saturn/shizuku_api.dart';
import 'package:saturn/shizuku_file.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

final Signal<bool> initialized = signals_core.signal(false);
final Signal<int> currentPageIndex = signals_core.signal(0);
Signal<PackageInfo?> package = signal(null);

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

Future<void> showConfirmationDialog(Widget title, Widget content,
    BuildContext context, void Function(BuildContext) onConfirm) async {
  showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
            title: title,
            content: content,
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => onConfirm(ctx), child: const Text("Confirm"))
            ],
          ));
}

class _AppState extends State<App> {
  static final List<Widget> pages = [
    const RecordsPage(),
    const EditXmlPage(),
    const GeneralPage(),
    const EquipmentPage()
  ];

  Future<bool> _tryToConnectToShizuku(BuildContext context) async {
    if (!(await BridgeApi.pingBinder() ?? false)) {
      return false;
    }

    if (!(await BridgeApi.checkPermission() ?? false)) {
      await BridgeApi.requestPermission(0);
      return await BridgeApi.checkPermission() ?? false;
    }

    return true;
  }

  Future<void> _tryToInitializeApp(BuildContext context) async {
    logger = constructLogger();
    await getExternalStorageDirectory(); // to create the data folder
    package.value = await PackageInfo.fromPlatform();
    await _tryToShowNotice();

    if (await _tryToConnectToShizuku(context)) {
      logger.i("Shizuku is available");
    } else {
      logger.e("Shizuku is not available");
      return;
    }

    var startResult = await BridgeApi.startBinderService();
    if (startResult.isNotEmpty) {
      logger.e("Error while starting binder service: $startResult");
      return;
    }
    var serviceAvailable = await BridgeApi.isBinderServiceAvailable();
    var tries = 0;
    while (!serviceAvailable && tries < 10) {
      setState(() {
        logger.i("Waiting for binder service...");
      });
      await Future.delayed(const Duration(milliseconds: 500));
      serviceAvailable = await BridgeApi.isBinderServiceAvailable();
      tries++;
    }
    if (serviceAvailable) {
      setState(() {
        logger.i("Binder service available");
      });
    } else {
      setState(() {
        logger.e("Timed out! Can't connect to the binder service");
      });
      return;
    }

    EnchantmentsManager.loadFromFiles().then((_) async {
      logger.i("Loaded enchantments");
      try {
        await _tryToLoadRecords();
        logger.i("Loaded ${RecordsManager.records.length} record(s)");
        setState(() {
          initialized.value = true;
        });
      } catch (e, s) {
        setState(() {
          logger.e("Unable to load the save file");
          logger.e("$e\n$s");
        });
      }
    }).onError((e, s) {
      setState(() {
        logger.e("Unable to load enchantments");
        logger.e("$e\n$s");
      });
    });
  }

  Future<void> _tryToLoadRecords() async {
    RecordsManager.records = await RecordsManager.loadRecords();
    if (RecordsManager.activeRecord == null) {
      logger.i("There are no records to load, creating a new one...");
      const path = "${RecordsManager.userdataPath}/users.xml";
      final tree = XmlDocument.parse(await readFile(path));
      final record =
          Record(tree, RecordMetadata("Save #1", const Uuid().v8(), true));
      RecordsManager.records.add(record);
      RecordsManager.activeRecord = record;
      RecordsManager.saveRecord(record);
    }
  }

  Future<void> _tryToShowNotice() async {
    final instance = await SharedPreferences.getInstance();
    if (instance.getBool("notifiedAboutFreedom") ?? false) {
      return;
    }

    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Read Me"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      "This app is FOSS (free). Download only from the official Codeberg repository: "),
                  TextButton(
                      onPressed: () => launchUrlString(Repo.repoUrl),
                      child: const Text(Repo.repoUrl))
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    child: const Text("Understood"))
              ],
            ));
    instance.setBool("notifiedAboutFreedom", true);
  }
  @override
  void initState() {
    super.initState();
    if (!initialized.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryToInitializeApp(context).then((_) {
          setState(() {});
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = logger.getStoredLogs();
    return Scaffold(
      appBar: const MainAppBar(),
      bottomNavigationBar: Watch((_) => initialized.value
          ? ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              child: NavigationBar(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceTint
                    .withValues(alpha: 0.1),
                destinations: [
                  NavigationDestination(
                      icon: Image.asset('assets/images/house.png',
                          width: 24, height: 24),
                      label: "Home"),
                  NavigationDestination(
                      icon: Image.asset('assets/images/file.png',
                          width: 24, height: 24),
                      label: "Edit XML"),
                  NavigationDestination(
                      icon: Image.asset('assets/images/wrench.png',
                          width: 24, height: 24),
                      label: "General"),
                  NavigationDestination(
                      icon: Image.asset('assets/images/sword.png',
                          width: 24, height: 24),
                      label: "Equipment")
                ],
                selectedIndex: currentPageIndex.value,
                onDestinationSelected: (int index) {
                  setState(() {
                    currentPageIndex.value = index;
                  });
                },
              ),
            )
          : const SizedBox.shrink()),
      body: Watch(
        (_) => initialized.value
            ? pages.elementAt(currentPageIndex.value)
            : Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(value: false, onChanged: null),
                      Text("Not initialized"),
                    ],
                  ),
                  const Text("This app requires Shizuku to run"),
                  TextButton(
                    child: const Text("Not working? Check README"),
                    onPressed: () {
                      launchUrlString(
                          "${Repo.repoUrl}/blob/master/README.md#-troubleshooting");
                    },
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final theme = Theme.of(ctx);
                        return Center(
                            child: Container(
                          width: constraints.maxWidth * 0.9 - 32,
                          height: constraints.maxHeight,
                          color: theme.brightness == Brightness.light
                              ? theme.colorScheme.surfaceContainerLowest
                              : theme.colorScheme.surfaceTint
                                  .withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListView.builder(
                              itemBuilder: (ctx, i) {
                                return Text(formatLogEntry(logs[i]));
                              },
                              itemCount: logs.length,
                            ),
                          ),
                        ));
                      },
                    ),
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await _tryToInitializeApp(context);
                      setState(() {});
                    },
                    label: const Text("Reinitialize"),
                    icon: const Icon(Icons.restart_alt),
                  ),
                  const SizedBox(
                    height: 64,
                  ),
                ],
              ),
      ),
    );
  }
}

</document_content>
</document>
<document index="2">
<source>lib/main.dart</source>
<document_content>
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:log_plus/log_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:saturn/app.dart';
import 'package:saturn/logic/item_database.dart';
import 'package:saturn/themes.dart';

Logs constructLogger() {
  return logger = Logs(
    storeLogLevel: LogLevel.verbose,
    printLogLevelWhenDebug: LogLevel.verbose,
    printLogLevelWhenRelease: LogLevel.verbose,
    storeLimit: 500,
  );
}

var logger = constructLogger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadPrefsValues();
  runApp(const RootApp());
}

Future<void> loadPrefsValues() async {
  final prefs = await SharedPreferences.getInstance();
  await loadThemeFromPrefs(prefs);
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  @override
  void initState() {
    super.initState();
    ItemDatabase.load().then((_) {
      logger.i("Loaded item databse");
    });
    ItemDatabase.loadTraits().then((traits) {
      ItemDatabase.traits = traits.toList();
      logger.i("Loaded item traits");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      (context) {
        final brightness_ = brightness.value;
        final useSystemColors_ = useSystemColors.value;
        final primaryColor_ = primaryColor.value;
        return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          ColorScheme lightColorScheme;
          ColorScheme darkColorScheme;

          if (lightDynamic != null && darkDynamic != null && useSystemColors_) {
            lightColorScheme = ColorScheme.fromSeed(
                seedColor: lightDynamic.primary, brightness: Brightness.light);
            darkColorScheme = ColorScheme.fromSeed(
                seedColor: darkDynamic.primary, brightness: Brightness.dark);
          } else {
            lightColorScheme = ColorScheme.fromSeed(seedColor: primaryColor_);
            darkColorScheme = ColorScheme.fromSeed(
                seedColor: primaryColor_, brightness: Brightness.dark);
          }

          supportsDynamicColors.value =
              lightDynamic != null && darkDynamic != null;

          final lightTheme = ThemeData(
              colorScheme: lightColorScheme,
              useMaterial3: true,
              scaffoldBackgroundColor: lightColorScheme.surfaceContainer);

          final darkTheme = ThemeData(
              colorScheme: darkColorScheme,
              useMaterial3: true,
              scaffoldBackgroundColor: darkColorScheme.surfaceContainer);
          return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: brightness_,
              title: "Saturn",
              home: const App());
        });
      },
    );
  }
}

</document_content>
</document>
<document index="3">
<source>lib/repo.dart</source>
<document_content>
class Repo {
  static const String repoUser = "onerdna";
  static const String repoName = "saturn";
  static const String repoUrl = "https://codeberg.org/$repoUser/$repoName";
  static const String latestRelease = "$repoUrl/releases/latest";
  static const String issueGeneral = "https://codeberg.org/onerdna/saturn/issues/new";
}

</document_content>
</document>
<document index="4">
<source>lib/shizuku_api.dart</source>
<document_content>
import 'package:flutter/services.dart';

class BridgeApi {
  static const _channel = MethodChannel('com.onerdna.saturn/shizuku');

  static Future<bool?> pingBinder() async {
    return await _channel.invokeMethod("pingBinder");
  }

  static Future<void> requestPermission(int requestCode) async {
    await _channel.invokeMethod("requestPermission", {
      "requestCode": requestCode,
    });
  }

  static Future<bool?> checkPermission() async {
    return await _channel.invokeMethod("checkPermission");
  }

  static Future<String?> runCommand(String command) async {
    return await _channel.invokeMethod("runCommand", {"command": command});
  }

  static Future<bool> isBinderServiceAvailable() async {
    return await _channel.invokeMethod("isBinderServiceAvailable");
  }

  static Future<String> startBinderService() async {
    return await _channel.invokeMethod("startBinderService");
  }
}

</document_content>
</document>
<document index="5">
<source>lib/shizuku_file.dart</source>
<document_content>
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:saturn/shizuku_api.dart';

Future<String> readFile(String path) async {
  final Directory directory = (await getExternalStorageDirectory())!;

  final file = makeTempFile(directory.path);

  validateCpOutput(
      file.path, await BridgeApi.runCommand("cp $path ${file.path}"));

  final contents = await file.readAsString();
  await BridgeApi.runCommand("rm ${file.path}");

  return contents;
}

String validateCpOutput(String path, String? output) {
  if (output == null) {
    throw FileSystemException('Unable to read file: unknown error', path);
  }

  if (output == 'cp: $path: No such file or directory') {
    throw FileSystemException('File does not exist', path);
  } else if (output == 'cp: $path: Permission denied') {
    throw FileSystemException('Permission denied', path);
  } else if (output == 'cp: $path: Is a directory') {
    throw FileSystemException('Path is a directory, not a file', path);
  }

  return output;
}

File makeTempFile(String path) {
  final rnd = List.generate(
      10,
      (_) => 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[
          Random().nextInt(62)]).join();
  return File("$path/.temp$rnd");
}

Future<void> writeFile(String targetPath, String contents) async {
  final directory = (await getExternalStorageDirectory())!;
  final file = makeTempFile(directory.path);
  await file.writeAsString(contents);
  validateCpOutput(
      targetPath, await BridgeApi.runCommand("cp ${file.path} $targetPath"));
  await BridgeApi.runCommand("rm ${file.path}");
}

</document_content>
</document>
<document index="6">
<source>lib/themes.dart</source>
<document_content>
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';

Signal<ThemeMode> brightness = signal(ThemeMode.system);
Signal<Color> primaryColor = signal(Colors.lightBlue);
Signal<bool> useSystemColors = signal(true);
Signal<bool> supportsDynamicColors = signal(false);

const colors = [
  Colors.red,
  Colors.green,
  Colors.blue,
  Colors.yellow,
  Colors.purple,
  Colors.cyan,
  Colors.redAccent,
  Colors.lightGreen,
  Colors.lightBlue,
  Colors.amber,
  Colors.deepPurple,
  Colors.teal,
  Color(0xffb33791),
  Color(0xff328e6e),
  Color(0xff00809d),
  Color(0xfffbdb93),
  Color(0xff511d43),
  Color(0xff222831)
];

Future<void> loadThemeFromPrefs(SharedPreferences prefs) async {
  int colorValue = prefs.getInt('primaryColor') ?? Colors.blue.toARGB32();
  brightness.value = ThemeMode.values
          .where((e) => prefs.getString("brightness") == e.toString())
          .firstOrNull ??
      ThemeMode.system;
  primaryColor.value = Color(colorValue);
  useSystemColors.value = prefs.getBool("useSystemColors") ?? true;
}

void setPrimaryColor(Color color) async {
  primaryColor.value = color;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('primaryColor', primaryColor.value.toARGB32());
}

void setBrightness(ThemeMode value) async {
  brightness.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('brightness', brightness.value.toString());
}

void setUseSystemColors(bool value) async {
  useSystemColors.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('useSystemColors', useSystemColors.value);
}

</document_content>
</document>
<document index="7">
<source>lib/logic/enchantment.dart</source>
<document_content>
import 'package:flutter/services.dart';
import 'package:saturn/logic/equipment_type.dart';
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

  static Future<void> loadFromFiles() async {
    enchantments.clear();
    groups.clear();
    final assets =
        (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
    for (final file in assets
        .where((key) => key.startsWith("assets/enchantments"))
        .toList()) {
      final tomlString = await rootBundle.loadString(file);
      final tomlMap = TomlDocument.parse(tomlString).toMap();
      final group = EnchantmentGroup.fromToml(tomlMap["group"]);
      tomlMap.remove("group");
      groups.add(group);
      enchantments.addAll(tomlMap.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        return Enchantment.fromToml(MapEntry(e.key, data), group);
      }));
      groups.sort((a, b) => a.order.compareTo(b.order));
    }
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

</document_content>
</document>
<document index="8">
<source>lib/logic/equipment.dart</source>
<document_content>
import 'package:saturn/logic/enchantment.dart';
import 'package:saturn/logic/equipment_type.dart';
import 'package:saturn/logic/item_database.dart';
import 'package:saturn/logic/record.dart';
import 'package:xml/xml.dart';

class UpgradeDelivery {
  DateTime time = DateTime.fromMillisecondsSinceEpoch(0);
  int level = 0;
  int upgrade = 0;

  String get upgradeLevel {
    return "$level${upgrade == 0 ? "00" : upgrade * 10}";
  }

  UpgradeDelivery(this.time, this.level, this.upgrade);
  UpgradeDelivery.fromXml(String upgradeLevel, String deliveryTime) {
    time = DateTime.fromMillisecondsSinceEpoch(int.parse(deliveryTime) * 1000);
    level = int.parse(upgradeLevel.substring(0, upgradeLevel.length - 2));
    upgrade = int.parse(upgradeLevel.substring(
        upgradeLevel.length - 2, upgradeLevel.length - 1));
  }
}

enum RecipeEnchantmentTier {
  simple("Simple"),
  medium("Medium"),
  mythical("Mythical");

  final String name;
  const RecipeEnchantmentTier(this.name);
}

class RecipeDelivery {
  DateTime time = DateTime.fromMillisecondsSinceEpoch(0);
  late RecipeEnchantmentTier tier;
  int itemLevel = 0;
  int playerLevel = 0;

  RecipeDelivery(this.tier, this.time, this.itemLevel, this.playerLevel);
  RecipeDelivery.fromXml(
      String tier, String deliveryTime, String itemLevel, String playerLevel) {
    time = DateTime.fromMillisecondsSinceEpoch(int.parse(deliveryTime) * 1000);
    this.itemLevel = int.parse(itemLevel);
    this.playerLevel = int.parse(playerLevel);
    this.tier = RecipeEnchantmentTier.values.firstWhere((e) => e.name == tier);
  }
}

class Equipment {
  final EquipmentType type;
  final String id;
  late final String name;
  late final String description;
  final String? acquireType;
  int level = 0;
  int upgrade = 0;
  UpgradeDelivery? upgradeDelivery;
  RecipeDelivery? recipeDelivery;

  static const minLevel = 1;
  static const maxLevel = 52;
  static const minUpgrade = 0;
  static const maxUpgrade = 4;

  List<AppliedEnchantment> enchantments = [];

  Equipment.fromUpgradeString(this.type, this.id, String upgradeLevel,
      {this.acquireType, this.upgradeDelivery, this.recipeDelivery}) {
    if (int.parse(upgradeLevel) < 0 ||
        int.parse(upgradeLevel) > maxLevel * 100 + maxUpgrade * 100) {
      upgradeLevel = "100";
    }
    level = int.parse(upgradeLevel.substring(0, upgradeLevel.length - 2));
    upgrade = int.parse(upgradeLevel.substring(
        upgradeLevel.length - 2, upgradeLevel.length - 1));

    name = ItemDatabase.getName(id);
    description = ItemDatabase.getDescription(id);
  }

  Equipment(this.type, this.id, this.level, this.upgrade, {this.acquireType}) {
    name = ItemDatabase.getName(id);
    description = ItemDatabase.getDescription(id);
  }

  String get _upgradeLevel {
    return "$level${upgrade == 0 ? "00" : upgrade * 10}";
  }

  XmlElement toXml(Record record) {
    List<XmlElement> children = [
      if (enchantments.isNotEmpty)
        XmlElement(XmlName("Enchantments"), [],
            enchantments.map((e) => e.toXml(type))),
      if (recipeDelivery != null)
        XmlElement(XmlName("RecipeDelivery"), [
          XmlAttribute(XmlName("Name"), recipeDelivery!.tier.name),
          XmlAttribute(
              XmlName("ItemLevel"), recipeDelivery!.itemLevel.toString()),
          XmlAttribute(
              XmlName("PlayerLevel"), recipeDelivery!.playerLevel.toString()),
          XmlAttribute(
              XmlName("DeliveryTime"),
              (recipeDelivery!.time.millisecondsSinceEpoch / 1000)
                  .toInt()
                  .toString()),
        ], [])
    ];
    return XmlElement(
        XmlName("Item"),
        [
          XmlAttribute(XmlName("Name"), id),
          XmlAttribute(
              XmlName("Equipped"), record.isEquipped(this) ? "1" : "0"),
          XmlAttribute(XmlName("Count"), "1"),
          XmlAttribute(XmlName("UpgradeLevel"), _upgradeLevel),
          XmlAttribute(
              XmlName("DeliveryTime"),
              upgradeDelivery == null
                  ? "-1"
                  : (upgradeDelivery!.time.millisecondsSinceEpoch / 1000)
                      .toInt()
                      .toString()),
          XmlAttribute(XmlName("DeliveryUpgradeLevel"),
              upgradeDelivery == null ? "-1" : upgradeDelivery!.upgradeLevel),
          XmlAttribute(XmlName("AcquireType"), acquireType ?? "Upgrade"),
        ],
        children);
  }
}

</document_content>
</document>
<document index="9">
<source>lib/logic/equipment_type.dart</source>
<document_content>
import 'package:saturn/logic/item_database.dart';

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

</document_content>
</document>
<document index="10">
<source>lib/logic/item_database.dart</source>
<document_content>
import 'package:flutter/services.dart';
import 'package:saturn/logic/enchantment.dart';
import 'package:saturn/logic/equipment_type.dart';
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

</document_content>
</document>
<document index="11">
<source>lib/logic/record.dart</source>
<document_content>
import 'package:saturn/logic/enchantment.dart';
import 'package:saturn/logic/equipment_type.dart';
import 'package:saturn/logic/equipment.dart';
import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';

enum Currency { coins, gems, greenOrbs, redOrbs, purpleOrbs }

class RecordMetadata {
  String name;
  String uuid;
  bool isActive;

  RecordMetadata(this.name, this.uuid, this.isActive);
  static RecordMetadata fromMap(Map map) {
    return RecordMetadata(map["name"], map["uuid"], map["is_active"]);
  }

  Map toMap() => {"name": name, "uuid": uuid, "is_active": isActive};
}

class Record {
  XmlDocument tree;
  late XmlElement root;
  final RecordMetadata metadata;
  Map<EquipmentType, List<Equipment>> equipment = {};
  Map<EquipmentType, String> equippedEquipment = {};

  static const String _warriorPath = "/Root/Warriors/Warrior[@FirstName][1]";
  static const String _disciplePath =
      "$_warriorPath/SessionSettings/ShowDojoDisciple/@Value";
  static const String _experiencePath = "$_warriorPath/@Experience";
  static const String _unlimitedEnergyPath =
      "$_warriorPath/Items/Item[@Name=\"Unlimited_Energy\"]";
  static final XmlElement _unlimitedEnergyElement = XmlElement(
    XmlName('Item'),
    [
      XmlAttribute(XmlName('Name'), 'Unlimited_Energy'),
      XmlAttribute(XmlName('Equipped'), '0'),
      XmlAttribute(XmlName('Count'), '1'),
      XmlAttribute(XmlName('UpgradeLevel'), '0'),
      XmlAttribute(XmlName('DeliveryTime'), '0'),
      XmlAttribute(XmlName('AcquireType'), 'Item'),
      XmlAttribute(XmlName('DeliveryUpgradeLevel'), '-1'),
    ],
  );

  Record(this.tree, this.metadata) {
    root = tree.findAllElements("Root").first;

    for (var e in ["1", "2", "3"]) {
      if (tree.xpath("//Currencies[@ForgeMaterial$e]").isEmpty) {
        tree.xpath("//Currencies").first.attributes.add(
              XmlAttribute(XmlName("ForgeMaterial$e"), "0"),
            );
      }
    }
    equipment = {for (var e in EquipmentType.values) e: _parseEquipment(e)};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Record &&
          runtimeType == other.runtimeType &&
          metadata.uuid == other.metadata.uuid;

  @override
  int get hashCode => metadata.uuid.hashCode;

  String? _getAttribute(String xpath) {
    return tree.xpath(xpath).whereType<XmlAttribute>().firstOrNull?.value;
  }

  void setAttribute(String xpath, String value) {
    tree.xpath(xpath).whereType<XmlAttribute>().first.value = value;
  }

  XmlElement _getWarrior() {
    return tree
        .findAllElements("Warrior")
        .firstWhere((e) => e.getAttribute("FirstName") != null);
  }

  int getCurrency(Currency currency) {
    return int.parse(_getAttribute(_getCurrencyPath(currency)) ?? "0");
  }

  String _getCurrencyPath(Currency currency) {
    switch (currency) {
      case Currency.coins:
        return "$_warriorPath/@Money";
      case Currency.gems:
        return "$_warriorPath/@Bonus";
      case Currency.greenOrbs:
        return "$_warriorPath/Currencies/@ForgeMaterial1";
      case Currency.redOrbs:
        return "$_warriorPath/Currencies/@ForgeMaterial2";
      case Currency.purpleOrbs:
        return "$_warriorPath/Currencies/@ForgeMaterial3";
    }
  }

  void setCurrency(Currency currency, int amount) {
    setAttribute(_getCurrencyPath(currency), amount.toString());
  }

  int get level {
    return int.parse(_getWarrior().getAttribute("Level") ?? "0");
  }

  set level(int level) {
    _getWarrior().setAttribute("Level", level.toString());
  }

  bool get isDiscipleEnabled {
    return _getAttribute(_disciplePath) == "1";
  }

  set isDiscipleEnabled(bool value) {
    setAttribute(_disciplePath, value ? "1" : "0");
  }

  int get experience {
    return int.tryParse(_getAttribute(_experiencePath) ?? "0") ?? 0;
  }

  set experience(int value) {
    setAttribute(_experiencePath, value.toString());
  }

  bool get isEnergyUnlimited {
    return tree.xpath(_unlimitedEnergyPath).isNotEmpty;
  }

  set isEnergyUnlimited(bool value) {
    final element = tree.xpath(_unlimitedEnergyPath);
    switch (value) {
      case true:
        if (!isEnergyUnlimited) {
          tree
              .xpath("$_warriorPath/Items")
              .whereType<XmlElement>()
              .first
              .children
              .add(_unlimitedEnergyElement);
        }
      case false:
        if (isEnergyUnlimited) {
          element.first.parent?.children.remove(element.first);
        }
    }
  }

  bool get showForge {
    return (_getAttribute("$_warriorPath/@ShowForge") ?? "0") == "1";
  }

  set showForge(bool value) {
    _getWarrior().setAttribute("ShowForge", value ? "1" : "0");
  }

  XmlElement get items {
    return (tree
            .xpath("$_warriorPath/Items")
            .whereType<XmlElement>()
            .firstOrNull ??
        XmlElement(XmlName("Items")));
  }

  List<Equipment> _parseEquipment(EquipmentType type) {
    final selectedId = _getWarrior().getAttribute(type.slot)!;

    return items.children
        .where((e) =>
            EquipmentTypeExtension.fromId(e.getAttribute("Name") ?? "") ==
                type &&
            e.getAttribute("UpgradeLevel") != null)
        .map((element) {
      final enchantments = element
          .findAllElements("Enchantments")
          .expand((n) => n.findElements("Perk"))
          .where((ench) =>
              EnchantmentsManager.findByEquipmentTypeId(
                  type, ench.getAttribute("Name") ?? "") !=
              null)
          .map((ench) {
        final enchantment = EnchantmentsManager.findByEquipmentTypeId(
            type, ench.getAttribute("Name")!)!;
        final aspect = enchantment.group.hasAspect
            ? int.tryParse(
                    (ench.getElement("Set") ?? XmlElement(XmlName("Set")))
                            .getAttribute("Aspect") ??
                        "0") ??
                0
            : null;
        return AppliedEnchantment(
            enchantment, aspect?.clamp(0, AppliedEnchantment.maxAspect));
      }).toList();
      final upgradeLevel = element.getAttribute("UpgradeLevel")!;
      final id = element.getAttribute("Name")!;
      final acquireType = element.getAttribute("AcquireType")!;
      UpgradeDelivery? upgradeDelivery = int.parse(
                      element.getAttribute("DeliveryTime") ?? "0") >
                  0 &&
              int.parse(element.getAttribute("DeliveryUpgradeLevel") ?? "0") > 0
          ? UpgradeDelivery.fromXml(
              element.getAttribute("DeliveryUpgradeLevel")!,
              element.getAttribute("DeliveryTime") ?? "0")
          : null;
      XmlElement? recipeDeliveryElement = element.getElement("RecipeDelivery");
      RecipeDelivery? recipeDelivery = recipeDeliveryElement == null
          ? null
          : RecipeDelivery.fromXml(
              recipeDeliveryElement.getAttribute("Name")!,
              recipeDeliveryElement.getAttribute("DeliveryTime")!,
              recipeDeliveryElement.getAttribute("ItemLevel")!,
              recipeDeliveryElement.getAttribute("PlayerLevel")!);
      final item = Equipment.fromUpgradeString(
          type, id, upgradeLevel == "0" ? "100" : upgradeLevel,
          acquireType: acquireType,
          upgradeDelivery: upgradeDelivery,
          recipeDelivery: recipeDelivery);
      item.enchantments = enchantments;
      if (id == selectedId) {
        setEquipped(item);
      }
      return item;
    }).toList();
  }

  Future<void> _saveEquipment() async {
    for (var k in EquipmentType.values) {
      items.children.removeWhere((e) =>
          EquipmentTypeExtension.fromId(e.getAttribute("Name") ?? "") == k &&
          e.getAttribute("UpgradeLevel") != null);
    }
    for (var v in equipment.values) {
      for (var item in v) {
        items.children.add(item.toXml(this));
      }
    }
  }

  Equipment? getEquipped(EquipmentType type) => equipment[type]
      ?.where((e) => e.id == equippedEquipment[type])
      .firstOrNull;
  void setEquipped(Equipment equipment) {
    _getWarrior().setAttribute(equipment.type.slot, equipment.id);
    equippedEquipment[equipment.type] = equipment.id;
  }

  bool isEquipped(Equipment equipment) =>
      equippedEquipment[equipment.type] == equipment.id;

  String get gameVersion =>
      _getAttribute("/Root/Versions/Version/@Value") ?? "1.0.0";
  String get dataVersion =>
      _getAttribute("/Root/Versions/DataVersion/@Value") ?? "1.0.0";
  int get launchIndex =>
      int.parse(_getAttribute("/Root/GameLaunchIndex/@Value") ?? "0");

  String get xml {
    _saveEquipment();
    return tree.toXmlString(pretty: true).replaceAllMapped(
          RegExp(r'(<[^>]+)(/>)'),
          (match) => match.group(1)!.endsWith(' ')
              ? match.group(0)!
              : '${match.group(1)} />',
        );
  }
}

</document_content>
</document>
<document index="12">
<source>lib/logic/records_manager.dart</source>
<document_content>
import 'dart:io';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saturn/logic/record.dart';
import 'package:saturn/main.dart';
import 'package:saturn/shizuku_api.dart';
import 'package:saturn/shizuku_file.dart';
import 'package:toml/toml.dart';
import 'package:xml/xml.dart';

class RecordsManager {
  static List<Record> records = [];
  static const userdataPath =
      "/sdcard/Android/data/com.sf2.de/files/userdata";

  static Record? get activeRecord =>
      records.where((e) => e.metadata.isActive == true).firstOrNull;

  static set activeRecord(Record? record) {
    for (var e in records) {
      e.metadata.isActive = false;
    }
    record?.metadata.isActive = true;
    try {
      _updateRecordsMetadata();
    } catch (e) {
      logger.e("updateRecordsMetadata: $e");
    }
  }

  static Future<void> saveRecord(Record record) async {
    final recordsDirectory = await _getRecordsDirectory();

    final metadataFile =
        File("${recordsDirectory.path}/${record.metadata.uuid}/metadata.toml");
    await metadataFile.create(recursive: true);

    metadataFile.writeAsString(
        TomlDocument.fromMap(record.metadata.toMap()).toString());

    final dataFile =
        File("${recordsDirectory.path}/${record.metadata.uuid}/data.xml");
    final xml = record.xml;

    dataFile.create();
    dataFile.writeAsString(xml);

    if (activeRecord == record) {
      await writeFile("$userdataPath/users.xml", xml);
      await writeFile("$userdataPath/users_backup.xml", xml);
    }
  }

  static void saveRecordWithToast(Record record) {
    saveRecord(record).then((result) {
      Fluttertoast.showToast(msg: "Saved successfully");
    }).onError((e, _) {
      Fluttertoast.showToast(msg: "Error occured while saving: $e");
    });
  }

  static String formatXml(String xml) {
    final reNewlines = RegExp(r'\n\s*');
    final noNewlines = xml.replaceAll(reNewlines, '');

    final reXmlDecl = RegExp(r'(<\?xml[^>]+\?>)\s*');
    final formatted =
        noNewlines.replaceAllMapped(reXmlDecl, (match) => match.group(1)!);

    return formatted;
  }

  static Future<Directory> _getRecordsDirectory() async {
    final externalStorage = (await getExternalStorageDirectory())!;
    final recordsDirectory = Directory("${externalStorage.path}/records");

    await recordsDirectory.create(recursive: true);
    return recordsDirectory;
  }

  static Future<List<Record>> loadRecords() async {
    final recordsDirectory = await _getRecordsDirectory();

    List<Record> records = [];

    for (final folder in recordsDirectory.listSync().whereType<Directory>()) {
      final record = await loadRecord(folder.path);
      records.add(record);
    }

    return records;
  }

  static Future<RecordMetadata> _loadRecordMetadata(String path) async {
    final metadataFile = File("$path/metadata.toml");

    return RecordMetadata.fromMap(
        TomlDocument.parse(await metadataFile.readAsString()).toMap());
  }

  static Future<Record> loadRecord(String path) async {
    final metadata = await _loadRecordMetadata(path);

    final dataPath =
        metadata.isActive ? "$userdataPath/users.xml" : "$path/data.xml";
    if (metadata.isActive) {
      BridgeApi.runCommand("cp $userdataPath/users.xml $path/data.xml");
    }

    final tree = XmlDocument.parse(await readFile(dataPath));
    return Record(tree, metadata);
  }

  static Future<void> _updateRecordsMetadata() async {
    final directory = await _getRecordsDirectory();

    for (final record in records) {
      final metadataFile =
          File("${directory.path}/${record.metadata.uuid}/metadata.toml");
      await metadataFile.create();
      await metadataFile.writeAsString(
          TomlDocument.fromMap(record.metadata.toMap()).toString());
    }
  }

  static Future<void> deleteRecord(Record record) async {
    final directory = await _getRecordsDirectory();
    await Directory("${directory.path}/${record.metadata.uuid}")
        .delete(recursive: true);
  }
}

</document_content>
</document>
<document index="13">
<source>lib/pages/about.dart</source>
<document_content>
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  void initState() {
    super.initState();
  }

  Widget _makeHyperlink(String link) {
    return TextButton(
        onPressed: () {
          launchUrlString(link);
        },
        child: Text(link));
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      (_) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Saturn",
                      style: TextStyle(fontSize: 32),
                    ),
                    const Divider(),
                    Column(
                      spacing: 0,
                      children: [
                        const Text("Fork of Stalker: ",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        _makeHyperlink("https://github.com/onerdna/stalker"),
                      ],
                    ),
                    const Divider(),
                    const Text(
                        "This app allows you to view and, optionally, edit save files for the game Shadow Fight 2: Definitive Edition 64, fan-made mod made by seby. The original game is owned by Nekki Limited. Editing is not recommended and is done at your own risk. As stated in the EULA, I am not responsible for any consequences resulting from such actions.",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Text("⚠️ Disclaimer",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Text(
                        "This project is not affiliated with, endorsed by, or in any way officially connected to Nekki, Banzai Games, or the developers of Shadow Fight 2. All trademarks, registered trademarks, product names, and company names or logos mentioned herein are the property of their respective owners.",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(),
                    const Text("Original author: Andreno",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Text("Reddit: ",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: _makeHyperlink(
                              "https://www.reddit.com/user/XAndrenoX/"),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text(
                        "Shadow Fight 2: Definitive Edition 64 author: seby7113",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Text("Reddit: ",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: _makeHyperlink(
                              "https://www.reddit.com/user/seby7113"),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text("Icons used: ",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    ...[
                      (
                        "Sword icons created by Iconic Panda - Flaticon",
                        "https://www.flaticon.com/free-icons/sword"
                      ),
                      (
                        "Home icons created by Vectors Market - Flaticon",
                        "https://www.flaticon.com/free-icons/home"
                      ),
                      (
                        "Document icons created by Roman Káčerek - Flaticon",
                        "https://www.flaticon.com/free-icons/document"
                      ),
                      (
                        "Wrench icons created by juicy_fish - Flaticon",
                        "https://www.flaticon.com/free-icons/wrench"
                      ),
                      (
                        "Katana icons created by Good Ware - Flaticon",
                        "https://www.flaticon.com/free-icons/katana"
                      ),
                      (
                        "Shuriken icons created by Freepik - Flaticon",
                        "https://www.flaticon.com/free-icons/shuriken"
                      ),
                      (
                        "Amulet icons created by Freepik - Flaticon",
                        "https://www.flaticon.com/free-icons/amulet"
                      ),
                      (
                        "Armor icons created by Nikita Golubev - Flaticon",
                        "https://www.flaticon.com/free-icons/armor"
                      ),
                      (
                        "Knight icons created by Freepik - Flaticon",
                        "https://www.flaticon.com/free-icons/knight"
                      ),
                      (
                        "Dojo icons created by juicy_fish - Flaticon",
                        "https://www.flaticon.com/free-icons/dojo"
                      ),
                      (
                        "Forge icons created by Freepik - Flaticon",
                        "https://www.flaticon.com/free-icons/forge"
                      ),
                      (
                        "Virus icons created by Freepik - Flaticon",
                        "https://www.flaticon.com/free-icons/virus"
                      ),
                      (
                        "Treasure icons created by kliwir art - Flaticon",
                        "https://www.flaticon.com/free-icons/treasure"
                      ),
                      (
                        "Weapon icons created by Smashicons - Flaticon",
                        "https://www.flaticon.com/free-icons/weapon"
                      )
                    ].map(
                      (e) => Column(
                        children: [
                          Text(e.$1,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: _makeHyperlink(e.$2),
                          ),
                        ],
                      ),
                    )
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

</document_content>
</document>
<document index="14">
<source>lib/pages/debug.dart</source>
<document_content>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:saturn/repo.dart';
import 'package:saturn/main.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:uuid/uuid.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  DebugPageState createState() => DebugPageState();
}

String formatLogEntry(e) =>
    "[${e['level'].toString().toUpperCase()}] ${e['message']}";

class DebugPageState extends State<DebugPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs Viewer'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            left: 40,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Share"),
                FloatingActionButton(
                  onPressed: () => _exportLogs(),
                  tooltip: "Share",
                  heroTag: "btn-share",
                  child: const Icon(Icons.share),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Report a bug"),
                FloatingActionButton(
                  heroTag: "btn-report",
                  onPressed: () {
                    launchUrlString(Repo.issueGeneral);
                  },
                  child: const Icon(Icons.report),
                ),
              ],
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 400),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: logger
                    .getStoredLogs()
                    .map((e) => Text(
                          formatLogEntry(e),
                          softWrap: false,
                          overflow: TextOverflow.visible,
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportLogs() async {
    final temp = await getTemporaryDirectory();
    final fileName = "log-${const Uuid().v8()}.txt";
    final file = File("${temp.path}/$fileName");
    await file.writeAsString(
        logger.getStoredLogs().map((e) => formatLogEntry(e)).join("\n"));
    await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, name: fileName, mimeType: "text/plain")]));
  }
}

</document_content>
</document>
<document index="15">
<source>lib/pages/equipment.dart</source>
<document_content>
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:saturn/logic/equipment_type.dart';
import 'package:saturn/logic/item_database.dart';
import 'package:saturn/pages/equipment_manager.dart';
import 'package:saturn/pages/inventory_view/inventory_view.dart';
import 'package:saturn/logic/records_manager.dart';

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
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 0,
          crossAxisSpacing: 8,
          childAspectRatio: 0.88),
      itemCount: gridItems.length,
      itemBuilder: (context, index) {
        final (label, imagePath, onTap) = gridItems[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
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
                  padding: const EdgeInsets.all(12),
                  shape: const ContinuousRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ),
                onPressed: onTap,
                child: Image.asset(imagePath, width: 64, height: 64),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        );
      },
    ));
  }
}

</document_content>
</document>
<document index="16">
<source>lib/pages/equipment_manager.dart</source>
<document_content>
import 'package:flutter/material.dart';
import 'package:saturn/logic/enchantment.dart';
import 'package:saturn/logic/equipment.dart';
import 'package:saturn/logic/equipment_type.dart';
import 'package:saturn/logic/item_database.dart';
import 'package:saturn/logic/records_manager.dart';
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
                    divisions: Equipment.maxUpgrade - Equipment.minUpgrade),
                Text("Upgrade level: $equipmentUpgrade"),
                Slider(
                    value: equipmentUpgrade.toDouble(),
                    onChanged: (v) =>
                        setState(() => equipmentUpgrade = v.toInt()),
                    min: Equipment.minUpgrade.toDouble(),
                    max: Equipment.maxUpgrade.toDouble(),
                    divisions: Equipment.maxUpgrade - Equipment.minUpgrade),
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
                  child: SplitFilledButton(
                      onLeftPressed: () {
                        // Add
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

</document_content>
</document>
<document index="17">
<source>lib/pages/general.dart</source>
<document_content>
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:saturn/ui/click_tooltip.dart';
import 'package:saturn/logic/record.dart';
import 'package:saturn/logic/records_manager.dart';

class GeneralPage extends StatefulWidget {
  const GeneralPage({super.key});

  @override
  State<GeneralPage> createState() => _GeneralPageState();
}

class Field {
  final String iconPath;
  final String name;
  final String? tooltip;
  final TextEditingController controller;
  final void Function(String) callback;

  Field(this.iconPath, this.name, this.controller, this.callback,
      {this.tooltip});
}

class _GeneralPageState extends State<GeneralPage> {
  late final List<Field> currencies;
  late final List<Field> progression;
  late final List<List<Field>> sections;

  @override
  void initState() {
    super.initState();
    currencies = [
      Field(
          "assets/images/coin.png",
          "Coins",
          TextEditingController(
              text: RecordsManager.activeRecord!
                  .getCurrency(Currency.coins)
                  .toString()), (value) {
        RecordsManager.activeRecord!
            .setCurrency(Currency.coins, int.tryParse(value) ?? 0);
      }),
      Field(
          "assets/images/ruby.png",
          "Gems",
          TextEditingController(
              text: RecordsManager.activeRecord!
                  .getCurrency(Currency.gems)
                  .toString()), (value) {
        RecordsManager.activeRecord!
            .setCurrency(Currency.gems, int.tryParse(value) ?? 0);
      }, tooltip: "Setting a value higher that 999 999 999 is not recommended"),
      Field(
          "assets/images/forge_green.png",
          "Green orbs",
          TextEditingController(
              text: RecordsManager.activeRecord!
                  .getCurrency(Currency.greenOrbs)
                  .toString()), (value) {
        RecordsManager.activeRecord!
            .setCurrency(Currency.greenOrbs, int.tryParse(value) ?? 0);
      }, tooltip: "Setting a value higher that 999 999 999 is not recommended"),
      Field(
          "assets/images/forge_red.png",
          "Red orbs",
          TextEditingController(
              text: RecordsManager.activeRecord!
                  .getCurrency(Currency.redOrbs)
                  .toString()), (value) {
        RecordsManager.activeRecord!
            .setCurrency(Currency.redOrbs, int.tryParse(value) ?? 0);
      }, tooltip: "Setting a value higher that 999 999 999 is not recommended"),
      Field(
          "assets/images/forge_purple.png",
          "Purple orbs",
          TextEditingController(
              text: RecordsManager.activeRecord!
                  .getCurrency(Currency.purpleOrbs)
                  .toString()), (value) {
        RecordsManager.activeRecord!
            .setCurrency(Currency.purpleOrbs, int.tryParse(value) ?? 0);
      }, tooltip: "Setting a value higher that 999 999 999 is not recommended"),
    ];

    progression = [
      Field(
          "assets/images/shuriken.png",
          "Level",
          TextEditingController(
              text: RecordsManager.activeRecord!.level.toString()), (value) {
        RecordsManager.activeRecord!.level = int.tryParse(value) ?? 1;
      }),
      Field(
          "assets/images/shuriken.png",
          "Experience",
          TextEditingController(
              text: RecordsManager.activeRecord!.experience.toString()),
          (value) {
        RecordsManager.activeRecord!.experience = int.tryParse(value) ?? 0;
      })
    ];

    sections = [currencies, progression];
  }

  Row _generateCheckbox(String name, String imagePath, bool value,
      void Function(bool?) onChanged) {
    return Row(
      children: [
        Image.asset(imagePath, width: 40, height: 40),
        const SizedBox(width: 20),
        Text(name),
        Checkbox(value: value, onChanged: onChanged)
      ],
    );
  }

  Container _generateSection(
      String title, Widget icon, String description, List<Field> fields,
      {bool initiallyExpanded = false}) {
    final theme = Theme.of(context);
    return Container(
      color: theme.brightness == Brightness.light
          ? theme.colorScheme.surfaceContainerLowest
          : theme.colorScheme.surfaceTint.withValues(alpha: 0.1),
      child: ExpansionTile(
          title: Wrap(spacing: 8, children: [icon, Text(title)]),
          initiallyExpanded: initiallyExpanded,
          subtitle: Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Text(description),
          ),
          childrenPadding: const EdgeInsets.only(left: 32),
          collapsedShape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent, width: 0),
          ),
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent, width: 0),
          ),
          children: fields.map((field) {
            return Row(
              children: [
                Image.asset(field.iconPath, width: 24, height: 24),
                const SizedBox(width: 5),
                Text(field.name),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  width: 150,
                  child: TextField(
                    controller: field.controller,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.only(top: 16, bottom: 0),
                      border: UnderlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (field.tooltip != null) ...[
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: ClickTooltip(
                      message: field.tooltip,
                      decoration: BoxDecoration(
                          border: Border.all(width: 1),
                          borderRadius: BorderRadius.circular(16),
                          color: Theme.of(context).canvasColor),
                      textStyle: Theme.of(context).textTheme.bodyMedium,
                      child: const Icon(Icons.info_outline),
                    ),
                  )
                ]
              ],
            );
          }).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = [
      _generateSection(
          "Currencies",
          Image.asset(
            "assets/images/treasure-chest.png",
            width: 24,
            height: 24,
          ),
          "Coins, Gems and Forge Materials",
          currencies,
          initiallyExpanded: true),
      _generateSection(
          "Progression",
          const Icon(Icons.arrow_upward, color: Colors.lightGreen, size: 24),
          "Levels and Experience",
          progression)
    ];
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ListView(children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, index) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final borderRadius = BorderRadius.vertical(
                    top: Radius.circular(index == 0 ? 24 : 4),
                    bottom:
                        Radius.circular(index == sections.length - 1 ? 24 : 4));
                return ClipRRect(
                    borderRadius: borderRadius, child: sections[index]);
              },
              itemCount: sections.length,
            ),
            const SizedBox(height: 20),
            _generateCheckbox("Dojo Disciple", "assets/images/dojo.png",
                RecordsManager.activeRecord!.isDiscipleEnabled, (value) {
              setState(() {
                RecordsManager.activeRecord!.isDiscipleEnabled = value ?? false;
              });
            }),
            const SizedBox(height: 6),
            _generateCheckbox("Unlimited Energy", "assets/images/lighting.png",
                RecordsManager.activeRecord!.isEnergyUnlimited, (value) {
              setState(() {
                RecordsManager.activeRecord!.isEnergyUnlimited = value ?? false;
              });
            }),
            const SizedBox(height: 6),
            _generateCheckbox("Show Forge", "assets/images/anvil.png",
                RecordsManager.activeRecord!.showForge, (value) {
              setState(() {
                RecordsManager.activeRecord!.showForge = value ?? false;
              });
            })
          ]),
        ),
      ),
      floatingActionButton:
          FloatingActionButton(onPressed: save, child: const Icon(Icons.save)),
    );
  }

  void save() {
    for (var section in sections) {
      for (var field in section) {
        field.callback(field.controller.text);
      }
    }

    RecordsManager.saveRecord(RecordsManager.activeRecord!).then((_) {
      Fluttertoast.showToast(msg: "Saved successfully");
    });
  }
}

</document_content>
</document>
<document index="18">
<source>lib/pages/settings.dart</source>
<document_content>
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:saturn/app.dart';
import 'package:saturn/pages/about.dart';
import 'package:saturn/themes.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext _) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: theme.colorScheme.surfaceContainer,
          title: const Text("Settings"),
          centerTitle: true),
      body: Watch((context) => Padding(
            padding:
                const EdgeInsets.only(top: 16, bottom: 32, left: 16, right: 16),
            child: Column(
              spacing: 16,
              children: [
                ListTile(
                  title: Text("Theme", style: theme.textTheme.titleLarge),
                  subtitle: const Text("Select desired application theme"),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      "Theme: ",
                      style: theme.textTheme.bodyLarge,
                    ),
                    DropdownButton<ThemeMode>(
                      value: brightness.value,
                      onChanged: (ThemeMode? value) => setState(() {
                        setBrightness(value!);
                      }),
                      items: ThemeMode.values
                          .map<DropdownMenuItem<ThemeMode>>((ThemeMode value) {
                        return DropdownMenuItem<ThemeMode>(
                          value: value,
                          child: Text(
                              "${value.name[0].toUpperCase()}${value.name.substring(1)}"),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                if (supportsDynamicColors.value)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      Text("Use system color scheme",
                          style: theme.textTheme.bodyLarge),
                      Switch(
                          value: useSystemColors.value,
                          onChanged: (value) => setUseSystemColors(value)),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: colors
                        .map((color) => GestureDetector(
                              onTap: () => setState(() {
                                setPrimaryColor(color);
                              }),
                              child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: color == primaryColor.value
                                        ? Border.all(
                                            width: 3,
                                            color: theme.colorScheme.primary)
                                        : Border.all(
                                            width: 1.5,
                                            color: theme.colorScheme.outline),
                                  )),
                            ))
                        .toList(),
                  ),
                ),
                const Divider(),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "About",
                        style: theme.textTheme.titleLarge,
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 32,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Center(
                    child: Text(
                  "${package.value!.packageName} ${package.value!.version}",
                  style: theme.textTheme.labelSmall,
                )),
              ],
            ),
          )),
    );
  }
}

</document_content>
</document>
<document index="19">
<source>lib/pages/edit_xml/edit_xml.dart</source>
<document_content>
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:saturn/pages/edit_xml/text_search_bar.dart';
import 'package:saturn/logic/record.dart';
import 'package:saturn/logic/records_manager.dart';
import 'package:xml/xml.dart';

class EditXmlPage extends StatefulWidget {
  const EditXmlPage({super.key});

  @override
  State<EditXmlPage> createState() => _EditXmlPageState();
}

class _EditXmlPageState extends State<EditXmlPage> {
  final textController = TextEditingController();
  final focusNode = FocusNode();
  final scrollController = ScrollController();
  bool searchCaseSensitivity = false;

  List<TextRange> searchMatches = [];
  int currentMatchIndex = 0;

  @override
  void initState() {
    super.initState();
    textController.text = RecordsManager.activeRecord!.xml;
  }

  @override
  void dispose() {
    textController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void save() {
    try {
      final tree = XmlDocument.parse(textController.text);
      RecordsManager.records[
              RecordsManager.records.indexOf(RecordsManager.activeRecord!)] =
          Record(tree, RecordsManager.activeRecord!.metadata);
      RecordsManager.saveRecordWithToast(RecordsManager.activeRecord!);
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => save(),
        child: const Icon(Icons.save),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: TextSearchBar(
                    onSubmitted: (query) {
                      if (query.trim().isEmpty) return;
                      setState(() {
                        _updateMatches(query.trim());
                        _jumpToMatch(currentMatchIndex);
                      });
                    },
                    onCleared: () {
                      setState(() {
                        currentMatchIndex = 0;
                        searchMatches.clear();
                      });
                      focusNode.unfocus();
                    },
                  ),
                ),
                Column(children: [
                  Row(children: [
                    IconButton.filled(
                        onPressed: () {
                          setState(() {
                            currentMatchIndex = _wrapIndex(
                                currentMatchIndex - 1,
                                0,
                                searchMatches.length - 1);
                          });
                          _jumpToMatch(currentMatchIndex);
                        },
                        icon: const Icon(Icons.arrow_upward)),
                    IconButton.filled(
                        onPressed: () {
                          setState(() {
                            currentMatchIndex = _wrapIndex(
                                currentMatchIndex + 1,
                                0,
                                searchMatches.length - 1);
                          });
                          _jumpToMatch(currentMatchIndex);
                        },
                        icon: const Icon(Icons.arrow_downward))
                  ]),
                  if (searchMatches.isNotEmpty)
                    Text(
                        "Current match: ${currentMatchIndex + 1}/${searchMatches.length}",
                        style: Theme.of(context).textTheme.bodySmall)
                ])
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Case sensitivity"),
              Checkbox(
                  value: searchCaseSensitivity,
                  onChanged: (value) {
                    setState(() {
                      searchCaseSensitivity = value ?? false;
                    });
                  }),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                thickness: 8,
                interactive: true,
                child: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  maxLines: null,
                  scrollController: scrollController, // Connect to TextField
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainer,
                    border: const OutlineInputBorder(),
                    hintText: 'Type here...',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _jumpToMatch(int index) {
    if (searchMatches.isEmpty || index >= searchMatches.length) return;

    final match = searchMatches[index];
    textController.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );

    focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final editableTextState =
          focusNode.context?.findAncestorStateOfType<EditableTextState>();
      editableTextState?.bringIntoView(TextPosition(offset: match.start));
    });
  }

  void _updateMatches(String query) {
    final text = textController.text;

    searchMatches.clear();
    if (query.isEmpty) return;

    final regExp =
        RegExp(RegExp.escape(query), caseSensitive: searchCaseSensitivity);
    searchMatches = regExp
        .allMatches(text)
        .map((m) => TextRange(start: m.start, end: m.end))
        .toList();

    currentMatchIndex = 0;
  }

  int _wrapIndex(int value, int min, int max) {
    final range = max - min + 1;
    return ((value - min) % range + range) % range + min;
  }
}

</document_content>
</document>
<document index="20">
<source>lib/pages/edit_xml/text_search_bar.dart</source>
<document_content>
import 'package:flutter/material.dart';

class TextSearchBar extends StatefulWidget {
  final void Function(String) onSubmitted;
  final VoidCallback onCleared;

  const TextSearchBar(
      {super.key, required this.onSubmitted, required this.onCleared});

  @override
  State<TextSearchBar> createState() => _TextSearchBarState();
}

class _TextSearchBarState extends State<TextSearchBar> {
  final controller = TextEditingController();
  final FocusNode focusNode = FocusNode();

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
    focusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchBar(
        hintText: "Search...",
        onSubmitted: widget.onSubmitted,
        controller: controller,
        focusNode: focusNode,
        trailing: [
          IconButton(
              onPressed: () {
                controller.clear();
                focusNode.unfocus();
                widget.onCleared();
              },
              icon: const Icon(Icons.clear))
        ]);
  }
}

</document_content>
</document>
<document index="21">
<source>lib/pages/inventory_view/equipment_search_bar.dart</source>
<document_content>
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

class EquipmentSearchBar extends StatefulWidget {
  final void Function(String) onChanged;
  final VoidCallback onCleared;

  const EquipmentSearchBar(
      {super.key, required this.onChanged, required this.onCleared});

  @override
  State<EquipmentSearchBar> createState() => _EquipmentSearchBarState();
}

class _EquipmentSearchBarState extends State<EquipmentSearchBar> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      hintText: "Search...",
      focusNode: focusNode,
      trailing: [
        IconButton(
            onPressed: () {
              controller.clear();
              focusNode.unfocus();
              widget.onCleared();
            },
            icon: const Icon(Icons.clear))
      ],
      onChanged: (text) => widget.onChanged(text),
      controller: controller,
    );
  }
}

</document_content>
</document>
<document index="22">
<source>lib/pages/inventory_view/inventory_view.dart</source>
<document_content>
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:saturn/app.dart';
import 'package:saturn/ui/click_tooltip.dart';
import 'package:saturn/ui/confirm_button.dart';
import 'package:saturn/logic/enchantment.dart';
import 'package:saturn/logic/equipment.dart';
import 'package:saturn/logic/equipment_type.dart';
import 'package:saturn/logic/item_database.dart';
import 'package:saturn/pages/inventory_view/equipment_search_bar.dart';
import 'package:saturn/pages/inventory_view/new_enchantment.dart';
import 'package:saturn/pages/inventory_view/new_item.dart';
import 'package:saturn/logic/records_manager.dart';

class InventoryTile extends StatelessWidget {
  final Widget title;
  final Widget subtitle;
  final List<Widget> children;
  const InventoryTile(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
        color: theme.brightness == Brightness.light
            ? theme.colorScheme.surfaceContainerLowest
            : theme.colorScheme.surfaceTint.withValues(alpha: 0.1),
        child: ExpansionTile(
          collapsedShape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent, width: 0),
          ),
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent, width: 0),
          ),
          title: Padding(padding: const EdgeInsets.only(top: 8), child: title),
          subtitle: Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: subtitle,
          ),
          children: [
            Divider(
              color: theme.colorScheme.surfaceContainer,
              thickness: 1,
            ),
            ...children
          ],
        ));
  }
}

class InventoryView extends StatefulWidget {
  final EquipmentType equipmentType;

  const InventoryView(this.equipmentType, {super.key});
  @override
  State<InventoryView> createState() => _InventoryViewState();

  static void save() {
    RecordsManager.saveRecordWithToast(RecordsManager.activeRecord!);
  }
}

class _InventoryViewState extends State<InventoryView> {
  List<Equipment> ownedEquipment = [];
  List<Equipment> foundEquipment = [];
  Iterable<String> suggestedEquipment = [];
  Iterable<String> existingEquipment = [];
  String query = "";

  @override
  void initState() {
    super.initState();
    ownedEquipment =
        RecordsManager.activeRecord!.equipment[widget.equipmentType]!;
    foundEquipment = ownedEquipment;
    existingEquipment = ItemDatabase.getEquipmentByType(widget.equipmentType);
    _searchEquipment(query);
  }

  @override
  Widget build(BuildContext context) {
    final suggested = _generateSuggestedEntries().toList();
    final owned = _generateOwnedEntries().toList();
    const foundOffset = 1;
    final suggestedOffset = foundOffset + owned.length + 1;
    final children = [
      Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 8, right: 8),
          child: Row(
            children: [
              Expanded(
                child: EquipmentSearchBar(
                  onChanged: (text) {
                    setState(() {
                      query = text.toLowerCase();
                      _searchEquipment(query);
                    });
                  },
                  onCleared: () {
                    setState(() {
                      foundEquipment = ownedEquipment;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ClickTooltip(
                message:
                    "RANGED_SUPER_MINE - Search by ID\nReaver - Search by name\nUnobtainable - Search by traits\nBecomes immobile - Search by description\nEquipped - Find currently equipped item",
                decoration: BoxDecoration(
                    border: Border.all(width: 1),
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).canvasColor),
                textStyle: Theme.of(context).textTheme.bodyMedium,
                child: const Icon(Icons.info_outline),
              ),
            ],
          )),
      ...owned,
      if (suggested.isNotEmpty)
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.only(left: 8.0, right: 8),
              child: Text(
                "Add new items",
                style: TextStyle(fontSize: 12),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
      ...suggested,
      SizedBox(
        width: double.maxFinite,
        child: FilledButton(
          onPressed: () {
            showDialog(
                context: context,
                builder: (ctx) => NewItem(
                    equipmentType: widget.equipmentType,
                    onPressed: (text) {
                      RecordsManager
                          .activeRecord!.equipment[widget.equipmentType]!
                          .add(Equipment(widget.equipmentType, text, 1, 0));
                      setState(() {
                        _searchEquipment(query);
                      });
                    }));
          },
          child: const Text("Add by ID"),
        ),
      ),
      const SizedBox(
        height: 80,
      )
    ];
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 32.0, left: 8, right: 8),
        child: Scrollbar(
            interactive: true,
            thickness: 10,
            child: ListView.separated(
                itemBuilder: (context, index) {
                  if ((index >= foundOffset &&
                          index < foundOffset + owned.length) ||
                      (index >= suggestedOffset &&
                          index < suggestedOffset + suggested.length)) {
                    final borderRadius = BorderRadius.vertical(
                        top: Radius.circular(
                            (index == foundOffset || index == suggestedOffset)
                                ? 24
                                : 4),
                        bottom: Radius.circular(
                            (index == owned.length - foundOffset + 1) ||
                                    (index ==
                                        suggestedOffset + suggested.length - 1)
                                ? 24
                                : 4));
                    return ClipRRect(
                        borderRadius: borderRadius, child: children[index]);
                  } else {
                    return children[index];
                  }
                },
                separatorBuilder: (_, __) => const SizedBox(height: 2.5),
                itemCount: children.length,
                shrinkWrap: true)),
      ),
      floatingActionButton: const FloatingActionButton(
        onPressed: InventoryView.save,
        child: Icon(Icons.save),
      ),
    );
  }

  Iterable<Widget> _generateOwnedEntries() {
    final theme = Theme.of(context);
    return foundEquipment.asMap().entries.map((entry) {
      final item = entry.value;
      final isEquipped = RecordsManager.activeRecord!.isEquipped(item);

      return InventoryTile(
        title: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkResponse(
                  onTap: () {
                    showConfirmationDialog(
                      const Text("Are you sure?"),
                      const Text(
                        "This item will be deleted from your inventory",
                        style: TextStyle(fontSize: 16),
                      ),
                      context,
                      (ctx) {
                        Navigator.of(ctx).pop();
                        setState(() {
                          foundEquipment.remove(item);
                          ownedEquipment.remove(item);
                          _searchEquipment(query);
                        });
                      },
                    );
                  },
                  radius: 16,
                  containedInkWell: true,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.delete),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 70),
                        child: Text(
                          item.name,
                          softWrap: true,
                          overflow: TextOverflow.fade,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: isEquipped
                            ? const Text(
                                "Equipped",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              )
                            : ConfirmButton(
                                onConfirmed: () {
                                  setState(() {
                                    RecordsManager.activeRecord!
                                        .setEquipped(item);
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text("Equip"),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        subtitle: Column(
          children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Text(item.id, style: const TextStyle(fontSize: 13))),
            const SizedBox(
              height: 12,
            ),
            _generateTraitsFor(item.id)
          ],
        ),
        children: [
          if (item.description.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4)),
                child: Container(
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(item.description),
                    )),
              ),
            ),
            Divider(
              color: theme.colorScheme.surfaceContainer,
              thickness: 1,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: theme.colorScheme.surfaceContainerLow,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  collapsedShape: const RoundedRectangleBorder(
                    side: BorderSide(color: Colors.transparent, width: 0),
                  ),
                  shape: const RoundedRectangleBorder(
                    side: BorderSide(color: Colors.transparent, width: 0),
                  ),
                  title: Row(
                    children: [
                      if (item.enchantments.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            showConfirmationDialog(
                                const Text("Are you sure?"),
                                const Text(
                                    "This will discard all enchantments from this item"),
                                context, (ctx) {
                              Navigator.of(ctx).pop();
                              setState(() {
                                item.enchantments.clear();
                              });
                            });
                          },
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                          ),
                        ),
                      const Text("Enchantments"),
                    ],
                  ),
                  children: [
                    ...item.enchantments.map((applied) => Padding(
                          padding: const EdgeInsets.only(left: 24.0),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Expanded(child: Text(applied.enchantment.name)),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      item.enchantments.remove(applied);
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete,
                                  ),
                                ),
                                const SizedBox(width: 20),
                              ],
                            ),
                            subtitle: applied.aspect == null
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(left: 12.0),
                                    child: Row(
                                      children: [
                                        Text("Aspect: ${applied.aspect}"),
                                        Expanded(
                                          child: Slider(
                                            value: applied.aspect!.toDouble(),
                                            onChanged: (v) {
                                              setState(() {
                                                applied.aspect = v.toInt();
                                              });
                                            },
                                            min: 0,
                                            max: AppliedEnchantment.maxAspect
                                                .toDouble(),
                                            divisions:
                                                AppliedEnchantment.maxAspect,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        )),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: ListTile(
                        title: OutlinedButton(
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (ctx) => NewEnchantmentDialog(
                                    enchantments:
                                        EnchantmentsManager.enchantments,
                                    type: widget.equipmentType,
                                    onPressed: (selected, amount) {
                                      setState(() {
                                        for (var i = 0; i < amount; i++) {
                                          item.enchantments.add(
                                            AppliedEnchantment(
                                              selected,
                                              selected.group.hasAspect
                                                  ? AppliedEnchantment.maxAspect
                                                  : null,
                                            ),
                                          );
                                        }
                                      });
                                      Navigator.of(ctx).pop();
                                    }));
                          },
                          child: const Text("Add..."),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (item.recipeDelivery != null) ...[
            Divider(
              color: theme.colorScheme.surfaceContainer,
              thickness: 1,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(spacing: 8, children: [
                      Row(
                        spacing: 16,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                              onPressed: () {
                                setState(() {
                                  item.recipeDelivery = null;
                                });
                              },
                              icon: const Icon(Icons.delete)),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              "Recipe in progress",
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      Text("Recipe: ${item.recipeDelivery!.tier.name}",
                          style: theme.textTheme.bodyLarge),
                      Text(
                        "Finishes: ${item.recipeDelivery!.time.toString()}",
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (item.recipeDelivery!.time
                          .isAfter(DateTime.now())) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                "Time left: ${item.recipeDelivery!.time.difference(DateTime.now())}",
                                style: theme.textTheme.bodyLarge),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: IconButton(
                                  onPressed: () {
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.replay)),
                            )
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              item.recipeDelivery!.time = DateTime.now();
                              Fluttertoast.showToast(msg: "Meido In Hebun!");
                            });
                          },
                          label: const Text("Skip"),
                          icon: const Icon(Icons.fast_forward),
                        )
                      ] else
                        Row(
                          spacing: 4,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: Colors.green),
                            Text("Already Done",
                                style: theme.textTheme.titleMedium),
                          ],
                        )
                    ]),
                  ),
                ),
              ),
            )
          ],
          if (item.upgradeDelivery != null) ...[
            Divider(
              color: theme.colorScheme.surfaceContainer,
              thickness: 1,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(spacing: 8, children: [
                      Row(
                        spacing: 16,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                              onPressed: () {
                                setState(() {
                                  item.upgradeDelivery = null;
                                });
                              },
                              icon: const Icon(Icons.delete)),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              "Upgrade in progress",
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      if (item.upgradeDelivery!.level != item.level)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 4,
                          children: [
                            Text("Level: ${item.level}",
                                style: theme.textTheme.bodyLarge),
                            const Icon(Icons.arrow_right_alt),
                            Text("${item.upgradeDelivery!.level}",
                                style: theme.textTheme.bodyLarge)
                          ],
                        ),
                      if (item.upgradeDelivery!.upgrade != item.upgrade &&
                          item.upgrade != 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 4,
                          children: [
                            Text("Upgrade level: ${item.upgrade}",
                                style: theme.textTheme.bodyLarge),
                            const Icon(Icons.arrow_right_alt),
                            Text("${item.upgradeDelivery!.upgrade}",
                                style: theme.textTheme.bodyLarge)
                          ],
                        ),
                      Text(
                        "Finishes: ${item.upgradeDelivery!.time.toString()}",
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (item.upgradeDelivery!.time
                          .isAfter(DateTime.now())) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                "Time left: ${item.upgradeDelivery!.time.difference(DateTime.now())}",
                                style: theme.textTheme.bodyLarge),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: IconButton(
                                  onPressed: () {
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.replay)),
                            )
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              item.upgradeDelivery!.time = DateTime.now();
                              Fluttertoast.showToast(msg: "Meido In Hebun!");
                            });
                          },
                          label: const Text("Skip"),
                          icon: const Icon(Icons.fast_forward),
                        )
                      ] else
                        Row(
                          spacing: 4,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: Colors.green),
                            Text("Already Done",
                                style: theme.textTheme.titleMedium),
                          ],
                        )
                    ]),
                  ),
                ),
              ),
            )
          ],
          Divider(
            color: theme.colorScheme.surfaceContainer,
            thickness: 1,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: ListTile(
              title: Row(
                children: [
                  Text("Level: ${item.level}"),
                  Slider(
                    value: item.level.toDouble(),
                    onChanged: (n) {
                      setState(() => item.level = n.toInt());
                    },
                    min: Equipment.minLevel.toDouble(),
                    max: Equipment.maxLevel.toDouble(),
                    divisions: Equipment.maxLevel - Equipment.minLevel,
                  ),
                ],
              ),
              subtitle: Row(
                children: [
                  Text(
                      "Upgrade level: ${item.upgrade == 0 ? "Not upgraded" : item.upgrade}"),
                  Expanded(
                    child: Slider(
                      value: item.upgrade.toDouble(),
                      onChanged: (n) {
                        setState(() => item.upgrade = n.toInt());
                      },
                      min: Equipment.minUpgrade.toDouble(),
                      max: Equipment.maxUpgrade.toDouble(),
                      divisions: Equipment.maxUpgrade - Equipment.minUpgrade,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          )
        ],
      );
    });
  }

  Iterable<Widget> _generateSuggestedEntries() {
    return suggestedEquipment.map((e) {
      final enchantments = ItemDatabase.getEnchantments(e).map((ench) =>
          DecoratedBox(
              decoration: BoxDecoration(
                  border: Border.all(width: 2, color: Color(ench.group.color)),
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 4.0, bottom: 4, right: 12, left: 12),
                child: Text(
                  ench.name,
                  style: const TextStyle(fontSize: 15),
                ),
              )));
      final description = ItemDatabase.getDescription(e);

      return InventoryTile(
        title: Row(
          spacing: 8,
          children: [
            InkResponse(
              onTap: () {
                final record = RecordsManager.activeRecord!;
                final equipment =
                    Equipment(widget.equipmentType, e, record.level, 0);
                equipment.enchantments = ItemDatabase.getEnchantments(e)
                    .map((ench) =>
                        AppliedEnchantment(ench, AppliedEnchantment.maxAspect))
                    .toList();
                setState(() {
                  record.equipment[widget.equipmentType]!.add(equipment);
                  _searchEquipment(query);
                });
              },
              radius: 16,
              containedInkWell: true,
              child: const Icon(Icons.add, size: 32),
            ),
            Text(ItemDatabase.getName(e)),
          ],
        ),
        subtitle: Column(
          children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Text(e, style: const TextStyle(fontSize: 13))),
            const SizedBox(
              height: 12,
            ),
            _generateTraitsFor(e)
          ],
        ),
        children: [
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                  top: 8, bottom: 16, left: 16, right: 16),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4)),
                child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(description),
                    )),
              ),
            ),
          if (enchantments.isNotEmpty) ...[
            const Align(
              alignment: Alignment.center,
              child: Text(
                "Enchantments: ",
                style: TextStyle(fontSize: 17),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(top: 8, bottom: 24, left: 8, right: 8),
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: enchantments.toList(),
                ),
              ),
            )
          ],
        ],
      );
    });
  }

  void _searchEquipment(String text) {
    foundEquipment = ownedEquipment
        .where((e) =>
            e.id.toLowerCase().contains(text) ||
            e.name.toLowerCase().contains(text) ||
            ItemDatabase.getDescription(e.id).toLowerCase().contains(text) ||
            ItemDatabase.getTraits(e.id)
                .where((t) =>
                    t.display.toLowerCase().contains(text) ||
                    t.id.toLowerCase().contains(text))
                .isNotEmpty ||
            ("equipped".contains(text) &&
                RecordsManager.activeRecord!.isEquipped(e)))
        .toList();

    final equipped = foundEquipment
        .indexWhere((item) => RecordsManager.activeRecord!.isEquipped(item));

    if (equipped != -1) {
      final equippedItem = foundEquipment.removeAt(equipped);
      foundEquipment.insert(0, equippedItem);
    }

    suggestedEquipment = existingEquipment
        .where((e) =>
            e.toLowerCase().contains(text) ||
            ItemDatabase.getName(e).toLowerCase().contains(text) ||
            ItemDatabase.getDescription(e).toLowerCase().contains(text) ||
            ItemDatabase.getTraits(e)
                .where((t) =>
                    t.display.toLowerCase().contains(text) ||
                    t.id.toLowerCase().contains(text))
                .isNotEmpty)
        .toSet()
        .difference(foundEquipment.map((e) => e.id).toSet());
  }

  Padding _generateTraitsFor(String id) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ItemDatabase.getTraits(id)
              .map((trait) => Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: Color(trait.color), width: 2),
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, top: 4, bottom: 4),
                      child: Text(
                        trait.display,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

</document_content>
</document>
<document index="23">
<source>lib/pages/inventory_view/new_enchantment.dart</source>
<document_content>
import 'package:flutter/material.dart';
import 'package:saturn/ui/click_tooltip.dart';
import 'package:saturn/logic/enchantment.dart';
import 'package:saturn/logic/equipment_type.dart';

class NewEnchantmentDialog extends StatefulWidget {
  final List<Enchantment> enchantments;
  final EquipmentType type;
  final void Function(Enchantment, int) onPressed;

  const NewEnchantmentDialog(
      {required this.enchantments,
      required this.type,
      required this.onPressed,
      super.key});

  @override
  State<NewEnchantmentDialog> createState() => _NewEnchantmentDialogState();
}

class _NewEnchantmentDialogState extends State<NewEnchantmentDialog> {
  int amountSliderValue = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Center(child: Text("Add an enchantment")),
      content: SizedBox(
        width: double.maxFinite,
        height: double.maxFinite,
        child: ListView(children: [
          Text("Amount: $amountSliderValue",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center),
          LayoutBuilder(
            builder: (ctx, constaints) {
              return Row(spacing: 0, children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      amountSliderValue = (amountSliderValue - 1).clamp(1, 100);
                    });
                  },
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(constaints.maxWidth * 0.15, 64)),
                  child: const Text("-",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
                ),
                SizedBox(
                  width: constaints.maxWidth * 0.7,
                  height: 64,
                  child: Slider(
                      min: 1,
                      max: 100,
                      value: amountSliderValue.toDouble(),
                      onChanged: (v) {
                        setState(() {
                          amountSliderValue = v.toInt();
                        });
                      }),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      amountSliderValue = (amountSliderValue + 1).clamp(1, 100);
                    });
                  },
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size(constaints.maxWidth * 0.15, 64)),
                  child: const Text("+",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
                )
              ]);
            },
          ),
          ...EnchantmentsManager.groups
              .map((group) => [
                    Center(
                      child: Text(
                        group.displayName,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    ...EnchantmentsManager.enchantments
                        .where((e) =>
                            e.idFor(widget.type) != null && e.group == group)
                        .map((ench) => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: FilledButton(
                                      onPressed: () => widget.onPressed(
                                          ench, amountSliderValue),
                                      child: Text(ench.name)),
                                ),
                                if (ench.description != null) ...[
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  ClickTooltip(
                                    message: ench.description,
                                    decoration: BoxDecoration(
                                        border: Border.all(width: 1),
                                        borderRadius: BorderRadius.circular(16),
                                        color: Theme.of(context).canvasColor),
                                    textStyle:
                                        Theme.of(context).textTheme.bodySmall,
                                    child: const Icon(Icons.info_outline),
                                  )
                                ]
                              ],
                            ))
                  ])
              .expand((e) => e)
        ]),
      ),
    );
  }
}

</document_content>
</document>
<document index="24">
<source>lib/pages/inventory_view/new_item.dart</source>
<document_content>
import "package:flutter/material.dart";
import 'package:saturn/logic/equipment_type.dart';

class NewItem extends StatefulWidget {
  final EquipmentType equipmentType;
  final void Function(String) onPressed;

  const NewItem(
      {required this.onPressed, required this.equipmentType, super.key});

  @override
  State<NewItem> createState() => _NewItemState();
}

class _NewItemState extends State<NewItem> {
  final controller = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add by ID"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: "Type ID here..."),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel")),
        TextButton(
          onPressed: () {
            widget.onPressed(controller.text);
            Navigator.of(context).pop();
          },
          child: const Text("Add to the inventory"),
        )
      ],
    );
  }
}

</document_content>
</document>
<document index="25">
<source>lib/pages/records/new_record.dart</source>
<document_content>
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:saturn/logic/record.dart';
import 'package:saturn/logic/records_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

class NewRecord extends StatefulWidget {
  final VoidCallback onCreated;

  const NewRecord({required this.onCreated, super.key});

  @override
  State<NewRecord> createState() => _NewRecordState();
}

class _NewRecordState extends State<NewRecord> {
  final controller = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create a new save record"),
      content: SizedBox(
        width: 400,
        height: 80,
        child: Column(
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: "Enter the name here..."),
            )
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cancel")),
        TextButton(
            onPressed: () async {
              final asset =
                  await rootBundle.loadString("assets/xml/defaultRecord.xml");
              final record = Record(XmlDocument.parse(asset),
                  RecordMetadata(controller.text, const Uuid().v8(), false));

              setState(() {
                RecordsManager.records.add(record);
                RecordsManager.saveRecord(record);
                Fluttertoast.showToast(msg: "Created a new save record");
              });
              Navigator.of(context).pop();
              widget.onCreated();
            },
            child: const Text("Continue"))
      ],
    );
  }
}

</document_content>
</document>
<document index="26">
<source>lib/pages/records/records.dart</source>
<document_content>
// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:saturn/app.dart';
import 'package:saturn/pages/records/new_record.dart';
import 'package:saturn/logic/record.dart';
import 'package:saturn/logic/records_manager.dart';
import 'package:xml/xml.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  Map<String, TextEditingController> controllers = {};

  @override
  void dispose() {
    super.dispose();
    for (var e in controllers.values) {
      e.dispose();
    }
  }

  Iterable<Widget> _generateRecordEntries(BuildContext context) {
    final theme = Theme.of(context);
    return RecordsManager.records.map((record) {
      final controllerKey = "${record.metadata.uuid}_name";
      if (controllers[controllerKey] == null) {
        controllers[controllerKey] =
            TextEditingController(text: record.metadata.name);
      }
      return Container(
        color: theme.brightness == Brightness.light
            ? theme.colorScheme.surfaceContainerLowest
            : theme.colorScheme.surfaceTint.withValues(alpha: 0.1),
        child: ExpansionTile(
          initiallyExpanded: RecordsManager.activeRecord! == record,
          collapsedShape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent, width: 0),
          ),
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: Colors.transparent, width: 0),
          ),
          title: Row(
            children: [
              IconButton(
                  onPressed: () {
                    if (record.metadata.isActive) {
                      Fluttertoast.showToast(
                          msg:
                              "You can’t delete a save slot while it’s set as active");
                    } else {
                      _showRecordDeletionDialog(context, record);
                    }
                  },
                  icon: const Icon(Icons.delete)),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: controllers["${record.metadata.uuid}_name"],
                  style: const TextStyle(fontSize: 19),
                  decoration:
                      const InputDecoration.collapsed(hintText: "Name..."),
                  onSubmitted: (value) {
                    if (record.metadata.name != value) {
                      record.metadata.name = value;
                      RecordsManager.saveRecord(record);
                    }
                  },
                ),
              ),
              const Spacer(),
              record.metadata.isActive
                  ? const Padding(
                      padding: EdgeInsets.only(right: 16.0),
                      child: Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Active",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  : const Text(""),
            ],
          ),
          subtitle: TextButton(
            child: Text(
              record.metadata.uuid,
              style: const TextStyle(fontSize: 13.8),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: record.metadata.uuid));
            },
          ),
          children: [
            Divider(
              color: theme.colorScheme.surfaceContainer,
              thickness: 1,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Column(
                children: [
                  _statTile(
                      "assets/images/shuriken.png", "Level", "${record.level}"),
                  _statTile("assets/images/coin.png", "Coins",
                      "${record.getCurrency(Currency.coins)}"),
                  _statTile("assets/images/ruby.png", "Gems",
                      "${record.getCurrency(Currency.gems)}"),
                  _statTile("assets/images/forge_green.png", "Green orbs",
                      "${record.getCurrency(Currency.greenOrbs)}"),
                  _statTile("assets/images/forge_red.png", "Red orbs",
                      "${record.getCurrency(Currency.redOrbs)}"),
                  _statTile("assets/images/forge_purple.png", "Purple orbs",
                      "${record.getCurrency(Currency.purpleOrbs)}"),
                ],
              ),
            ),
            Divider(
              color: theme.colorScheme.surfaceContainer,
              thickness: 1,
            ),
            ...[
              "Game version: ${record.gameVersion}",
              "Data version: ${record.dataVersion}",
              "Launch index: ${record.launchIndex}"
            ].map((e) => Text(
                  e,
                  style: theme.textTheme.labelMedium,
                )),
            Divider(
              color: theme.colorScheme.surfaceContainer,
              thickness: 1,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                    onPressed: () {
                      setState(() {
                        import(record);
                      });
                    },
                    icon: const Icon(Icons.download)),
                const SizedBox(
                  width: 4,
                ),
                record.metadata.isActive
                    ? FilledButton(
                        onPressed: () {
                          RecordsManager.saveRecordWithToast(
                              RecordsManager.activeRecord!);
                        },
                        child: const Text("Overwrite on disk"))
                    : FilledButton(
                        onPressed: () {
                          setState(() {
                            RecordsManager.activeRecord = record;
                            RecordsManager.saveRecord(record);
                          });
                        },
                        child: const Text("Set as active")),
                const SizedBox(
                  width: 4,
                ),
                IconButton.filled(
                    onPressed: () => export(record),
                    icon: const Icon(Icons.share)),
              ],
            ),
            const SizedBox(height: 8)
          ],
        ),
      );
    });
  }

  Widget _statTile(String iconPath, String label, String value) {
    return ListTile(
      title: Row(
        children: [
          Image.asset(iconPath, width: 24, height: 24),
          const SizedBox(width: 5),
          Text(
            "$label: $value",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> export(Record save) async {
    final temp = await getTemporaryDirectory();
    final file = File("${temp.path}/users.xml");
    await file.writeAsString(save.xml);
    await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, name: "users.xml", mimeType: "text/plain")]));
  }

  void import(Record record) {
    showConfirmationDialog(
        const Text("Are you sure?"),
        const Text(
          "This will overwrite your save file with a new one!",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        context, (ctx) async {
      Navigator.of(ctx).pop();
      final result = await FilePicker.platform.pickFiles(
          dialogTitle: "Pick a save file",
          type: FileType.custom,
          allowedExtensions: ["xml"]);
      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        final file = File(result.files.first.path!);
        final content = await file.readAsString();

        try {
          final newSave = Record(XmlDocument.parse(content), record.metadata);
          setState(() {
            RecordsManager.records[RecordsManager.records.indexOf(record)] =
                newSave;
          });
          RecordsManager.saveRecord(newSave);
          Fluttertoast.showToast(msg: "Successfully imported the save file");
        } catch (e) {
          Fluttertoast.showToast(msg: e.toString());
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _generateRecordEntries(context).toList();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Center(
            child: Text(
              "© 2025 Andreno. All rights reserved.",
              style: TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final borderRadius = BorderRadius.vertical(
                  top: Radius.circular(index == 0 ? 24 : 4),
                  bottom:
                      Radius.circular(index == entries.length - 1 ? 24 : 4));
              return ClipRRect(
                  borderRadius: borderRadius, child: entries[index]);
            },
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.maxFinite,
            child: FilledButton.icon(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (ctx) => NewRecord(onCreated: () {
                            setState(() {});
                          }));
                },
                label: const Icon(Icons.add)),
          )
        ],
      ),
    );
  }

  Future<void> _showRecordDeletionDialog(
      BuildContext context, Record record) async {
    await showConfirmationDialog(
        const Text("Are you sure?"),
        const Text(
          "This will forever delete this save slot with all of the contents!",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        context, (ctx) async {
      Navigator.of(ctx).pop();
      setState(() {
        RecordsManager.records.remove(record);
      });
      await RecordsManager.deleteRecord(record);
    });
  }
}

</document_content>
</document>
<document index="27">
<source>lib/ui/app_bar.dart</source>
<document_content>
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:saturn/app.dart';
import 'package:saturn/pages/debug.dart';
import 'package:saturn/pages/settings.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({super.key});

  @override
  Widget build(BuildContext _) {
    return Watch((context) => AppBar(
          toolbarHeight: 200,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          title: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.bug_report),
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) => const DebugPage())),
                          )),
                      if (package.value?.version != null)
                        Text(
                          "v${package.value?.version}",
                          style: const TextStyle(fontSize: 16),
                        ),
                    ],
                  )),
              const Center(child: Text("Saturn")),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const SettingsPage())),
                  icon: const Icon(Icons.settings),
                ),
              ),
            ],
          ),
        ));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

</document_content>
</document>
<document index="28">
<source>lib/ui/click_tooltip.dart</source>
<document_content>
import 'package:flutter/material.dart';

class ClickTooltip extends StatefulWidget {
  final String? message;
  final BoxDecoration? decoration;
  final TextStyle? textStyle;
  final Widget child;
  const ClickTooltip(
      {this.message,
      this.decoration,
      this.textStyle,
      required this.child,
      super.key});

  @override
  ClickTooltipState createState() => ClickTooltipState();
}

class ClickTooltipState extends State<ClickTooltip> {
  final GlobalKey _key = GlobalKey();

  void _showTooltip() {
    final dynamic tooltip = _key.currentState;
    tooltip.ensureTooltipVisible();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      key: _key,
      message: widget.message,
      decoration: widget.decoration,
      textStyle: widget.textStyle,
      child: GestureDetector(
        onTap: _showTooltip,
        child: widget.child,
      ),
    );
  }
}

</document_content>
</document>
<document index="29">
<source>lib/ui/confirm_button.dart</source>
<document_content>
import 'dart:async';
import 'package:flutter/material.dart';

class ConfirmButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  final Widget child;
  final ButtonStyle style;

  const ConfirmButton(
      {super.key,
      required this.onConfirmed,
      required this.child,
      this.style = const ButtonStyle()});

  @override
  State<ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<ConfirmButton> {
  bool _confirming = false;
  Timer? _resetTimer;

  void _onPressed() {
    if (_confirming) {
      widget.onConfirmed();
      _resetConfirming();
    } else {
      setState(() {
        _confirming = true;
      });
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _confirming = false;
          });
        }
      });
    }
  }

  void _resetConfirming() {
    _resetTimer?.cancel();
    setState(() {
      _confirming = false;
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: widget.style.copyWith(
          backgroundColor:
              WidgetStatePropertyAll(_confirming ? Colors.red : null)),
      onPressed: _onPressed,
      child: _confirming
          ? const Padding(
              padding: EdgeInsets.only(left: 6, right: 6, top: 1, bottom: 1),
              child: Text('Are you sure?'),
            )
          : widget.child,
    );
  }
}

</document_content>
</document>
<document index="30">
<source>lib/ui/split_filled_button.dart</source>
<document_content>
import 'package:flutter/material.dart';

class SplitFilledButton extends StatelessWidget {
  final VoidCallback onLeftPressed;
  final VoidCallback onRightPressed;
  final Widget leftChild;
  final Widget rightChild;

  const SplitFilledButton({
    super.key,
    required this.onLeftPressed,
    required this.onRightPressed,
    required this.leftChild,
    required this.rightChild,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onLeftPressed,
            style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16)))),
            child: leftChild,
          ),
        ),
        Container(
          width: 1,
          height: 8,
          color: colorScheme.onPrimary.withValues(alpha: 0.12),
        ),
        Expanded(
          child: FilledButton(
            onPressed: onRightPressed,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16))),
            ),
            child: rightChild,
          ),
        ),
      ],
    );
  }
}

</document_content>
</document>
</documents>
