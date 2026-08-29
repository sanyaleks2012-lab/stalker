import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toml/toml.dart';
import 'package:xml/xml.dart';

void main() {
  runApp(const SaturnWebApp());
}

class ItemMetadata {
  final String id;
  final String name;
  final String description;

  ItemMetadata({
    required this.id,
    required this.name,
    required this.description,
  });
}

class SaturnWebApp extends StatelessWidget {
  const SaturnWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saturn Web Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const WebHomePage(),
    );
  }
}

class WebHomePage extends StatefulWidget {
  const WebHomePage({super.key});

  @override
  State<WebHomePage> createState() => _WebHomePageState();
}

class _WebHomePageState extends State<WebHomePage> {
  final Map<String, ItemMetadata> _tomlDatabase = {};
  XmlDocument? _xmlDocument;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadTomlFiles();
    _loadSampleXml();
    setState(() => _isLoading = false);
  }

  /// Автоматический поиск и загрузка всех TOML-файлов из assets/toml/
  Future<void> _loadTomlFiles() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      final tomlPaths = manifestMap.keys.where(
        (String key) => key.startsWith('assets/toml/') && key.endsWith('.toml'),
      );

      for (final path in tomlPaths) {
        final content = await rootBundle.loadString(path);
        final parser = TomlDocument.parse(content).toMap();

        parser.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            final name = value['Name']?.toString() ?? key;
            final desc = value['Description']?.toString() ?? '';
            _tomlDatabase[key] = ItemMetadata(
              id: key,
              name: name,
              description: desc,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Ошибка при сканировании или парсинге TOML: $e');
    }
  }

  /// Загрузка базовой структуры XML
  void _loadSampleXml() {
    const rawXml = '''<?xml version="1.0" encoding="utf-8"?>
<Root>
  <Warriors>
    <Warrior ID="1" FirstName="NAME_AGONY" Level="8">
      <Items>
        <Item Name="Body" Equipped="1" Count="1"/>
        <Item Name="WEAPON_KNUCKLES" Equipped="1" Count="1" UpgradeLevel="730">
          <Enchantments>
            <Perk Name="PERK_ITEM_SPECIAL_LIFESTEAL_WEAPON">
              <Set Aspect="9999" />
            </Perk>
          </Enchantments>
        </Item>
      </Items>
    </Warrior>
  </Warriors>
</Root>''';
    _xmlDocument = XmlDocument.parse(rawXml);
  }

  XmlElement? _getItemsNode() {
    return _xmlDocument
        ?.findAllElements('Warrior')
        .firstOrNull
        ?.findElements('Items')
        .firstOrNull;
  }

  List<XmlElement> _getXmlItems() {
    final itemsNode = _getItemsNode();
    if (itemsNode == null) return [];
    return itemsNode.findElements('Item').toList();
  }

  void _addItem(String id) {
    final itemsNode = _getItemsNode();
    if (itemsNode == null) return;

    final newItem = XmlElement(
      XmlName('Item'),
      [
        XmlAttribute(XmlName('Name'), id),
        XmlAttribute(XmlName('Equipped'), '0'),
        XmlAttribute(XmlName('Count'), '1'),
        XmlAttribute(XmlName('UpgradeLevel'), '1'),
        XmlAttribute(XmlName('AcquireType'), 'Item'),
      ],
    );

    setState(() {
      itemsNode.children.add(newItem);
    });
  }

  void _removeItem(XmlElement itemNode) {
    setState(() {
      itemNode.replace(const []);
    });
  }

  void _addEnchantment(XmlElement itemNode, String perkName) {
    var enchantmentsNode = itemNode.findElements('Enchantments').firstOrNull;
    if (enchantmentsNode == null) {
      enchantmentsNode = XmlElement(XmlName('Enchantments'));
      itemNode.children.add(enchantmentsNode);
    }

    final perkNode = XmlElement(
      XmlName('Perk'),
      [XmlAttribute(XmlName('Name'), perkName)],
      [
        XmlElement(
          XmlName('Set'),
          [XmlAttribute(XmlName('Aspect'), '100')],
        )
      ],
    );

    setState(() {
      enchantmentsNode!.children.add(perkNode);
    });
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Добавить предмет из TOML'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: _tomlDatabase.isEmpty
                ? const Center(child: Text('TOML базы пустые (добавьте .toml в assets/toml/)'))
                : ListView.builder(
                    itemCount: _tomlDatabase.length,
                    itemBuilder: (context, index) {
                      final item = _tomlDatabase.values.elementAt(index);
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text('${item.id}\n${item.description}'),
                        onTap: () {
                          _addItem(item.id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  void _showAddEnchantmentDialog(XmlElement itemNode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Добавить зачарование (Perk)'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: _tomlDatabase.isEmpty
                ? const Center(child: Text('TOML базы пустые'))
                : ListView.builder(
                    itemCount: _tomlDatabase.length,
                    itemBuilder: (context, index) {
                      final item = _tomlDatabase.values.elementAt(index);
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.id),
                        onTap: () {
                          _addEnchantment(itemNode, item.id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final items = _getXmlItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saturn Web Panel — XML & TOML Editor'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddItemDialog,
            tooltip: 'Добавить предмет',
          ),
        ],
      ),
      body: Row(
        children: [
          // Список загруженных элементов из TOML
          Expanded(
            flex: 1,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOML База (${_tomlDatabase.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(),
                    Expanded(
                      child: _tomlDatabase.isEmpty
                          ? const Center(
                              child: Text(
                                'Нет файлов в assets/toml/',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView(
                              children: _tomlDatabase.values.map((meta) {
                                return ListTile(
                                  dense: true,
                                  title: Text(meta.name),
                                  subtitle: Text('${meta.id}\n${meta.description}'),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Элементы в XML
          Expanded(
            flex: 2,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Предметы в XML (${items.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final itemNode = items[index];
                          final id = itemNode.getAttribute('Name') ?? '';
                          final meta = _tomlDatabase[id];
                          final enchantments = itemNode
                              .findElements('Enchantments')
                              .firstOrNull
                              ?.findElements('Perk')
                              .toList();

                          return ExpansionTile(
                            title: Text(meta?.name ?? id),
                            subtitle: Text(
                              'ID: $id | Equipped: ${itemNode.getAttribute('Equipped')}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _removeItem(itemNode),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (enchantments != null && enchantments.isNotEmpty) ...[
                                      const Text(
                                        'Зачарования:',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      ...enchantments.map((perk) {
                                        final perkName = perk.getAttribute('Name') ?? '';
                                        final perkMeta = _tomlDatabase[perkName];
                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                                          title: Text(perkMeta?.name ?? perkName),
                                          subtitle: Text('ID: $perkName'),
                                        );
                                      }),
                                    ],
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.flash_on, size: 18),
                                        label: const Text('Добавить зачарование'),
                                        onPressed: () => _showAddEnchantmentDialog(itemNode),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
