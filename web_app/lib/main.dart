import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;
import 'package:toml/toml.dart';
import 'package:xml/xml.dart';

void main() {
  runApp(const SaturnWebApp());
}

class ItemMetadata {
  final String id;
  final String name;
  final String description;
  final List<String> enchantments;
  final List<String> traits;

  ItemMetadata({
    required this.id,
    required this.name,
    this.description = '',
    this.enchantments = const [],
    this.traits = const [],
  });
}

class SaturnWebApp extends StatelessWidget {
  const SaturnWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saturn Web Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF673AB7),
        scaffoldBackgroundColor: const Color(0xFF0F0F14),
        cardTheme: CardThemeData(
          color: const Color(0xFF181820),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
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
  static const List<String> _tomlFiles = [
    'assets/toml/armor.toml',
    'assets/toml/complex_1.toml',
    'assets/toml/complex_2.toml',
    'assets/toml/complex_3.toml',
    'assets/toml/helm.toml',
    'assets/toml/magic.toml',
    'assets/toml/medium.toml',
    'assets/toml/ranged.toml',
    'assets/toml/simple.toml',
    'assets/toml/special_1.toml',
    'assets/toml/special_2.toml',
    'assets/toml/special_3.toml',
    'assets/toml/traits.toml',
    'assets/toml/weapon.toml',
  ];

  final Map<String, ItemMetadata> _tomlDatabase = {};
  final Set<String> _allPerks = {};
  XmlDocument? _xmlDocument;
  String _currentFileName = 'users.xml';
  bool _isLoading = true;

  String _searchTomlQuery = '';
  String _searchXmlQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadTomlFiles();
    _loadDefaultXml();
    setState(() => _isLoading = false);
  }

  Future<void> _loadTomlFiles() async {
    for (final path in _tomlFiles) {
      try {
        final content = await rootBundle.loadString(path);
        _parseTomlString(content);
      } catch (e) {
        debugPrint('Ошибка загрузки $path: $e');
      }
    }
  }

  void _parseTomlString(String content) {
    try {
      final parser = TomlDocument.parse(content).toMap();
      parser.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final rawName = value['name']?.toString() ?? value['Name']?.toString() ?? '';
          final desc = value['description']?.toString() ?? value['Description']?.toString() ?? '';

          final enchantmentsRaw = value['enchantments'] ?? value['Enchantments'];
          final List<String> enchantments = [];
          if (enchantmentsRaw is List) {
            for (var e in enchantmentsRaw) {
              final str = e.toString().trim().toUpperCase();
              final formatted = str.startsWith('PERK_') ? str : 'PERK_$str';
              enchantments.add(formatted);
              _allPerks.add(formatted);
            }
          }

          final traitsRaw = value['traits'] ?? value['Traits'];
          final List<String> traits = [];
          if (traitsRaw is List) {
            for (var t in traitsRaw) {
              traits.add(t.toString());
            }
          }

          // Если сам ключ или имя начинается с PERK_, добавляем его в общую базу перков тоже
          final upperKey = key.trim().toUpperCase();
          if (upperKey.startsWith('PERK_')) {
            _allPerks.add(upperKey);
          }

          _tomlDatabase[key] = ItemMetadata(
            id: key,
            name: rawName.trim().isEmpty ? key : rawName,
            description: desc,
            enchantments: enchantments,
            traits: traits,
          );
        }
      });
    } catch (e) {
      debugPrint('Ошибка парсинга TOML: $e');
    }
  }

  void _loadDefaultXml() {
    const rawXml = '''<?xml version="1.0" encoding="utf-8"?>
<Root>
  <Warriors>
    <Warrior ID="1" FirstName="NAME_AGONY">
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

  void _pickAndLoadXml() {
    final uploadInput = html.FileUploadInputElement()..accept = '.xml';
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();

        reader.onLoadEnd.listen((e) {
          try {
            final content = reader.result as String;
            setState(() {
              _xmlDocument = XmlDocument.parse(content);
              _currentFileName = file.name;
            });
            _showSnackBar('Файл $_currentFileName успешно открыт', Colors.green);
          } catch (err) {
            _showSnackBar('Ошибка чтения XML файла', Colors.redAccent);
          }
        });

        reader.readAsText(file);
      }
    });
  }

  void _pickAndLoadToml() {
    final uploadInput = html.FileUploadInputElement()
      ..accept = '.toml'
      ..multiple = true;
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null) {
        for (var file in files) {
          final reader = html.FileReader();
          reader.onLoadEnd.listen((e) {
            final content = reader.result as String;
            setState(() {
              _parseTomlString(content);
            });
          });
          reader.readAsText(file);
        }
        _showSnackBar('TOML пресеты импортированы', Colors.deepPurpleAccent);
      }
    });
  }

  void _downloadXml() {
    if (_xmlDocument == null) return;

    final xmlString = _xmlDocument!.toXmlString(pretty: true, indent: '  ');
    final bytes = utf8.encode(xmlString);
    final blob = html.Blob([bytes], 'text/xml');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', _currentFileName)
      ..click();

    html.Url.revokeObjectUrl(url);
    _showSnackBar('Файл $_currentFileName сохранен', Colors.green);
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
    final allItems = itemsNode.findElements('Item').toList();
    if (_searchXmlQuery.isEmpty) return allItems;

    return allItems.where((item) {
      final id = item.getAttribute('Name') ?? '';
      final name = _tomlDatabase[id]?.name ?? '';
      return id.toLowerCase().contains(_searchXmlQuery.toLowerCase()) ||
          name.toLowerCase().contains(_searchXmlQuery.toLowerCase());
    }).toList();
  }

  String _formatPerkName(String rawPerk) {
    final upper = rawPerk.trim().toUpperCase();
    return upper.startsWith('PERK_') ? upper : 'PERK_$upper';
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

    final meta = _tomlDatabase[id];
    if (meta != null && meta.enchantments.isNotEmpty) {
      final enchantmentsNode = XmlElement(XmlName('Enchantments'));
      for (final ench in meta.enchantments) {
        enchantmentsNode.children.add(
          XmlElement(
            XmlName('Perk'),
            [XmlAttribute(XmlName('Name'), ench)],
            [
              XmlElement(
                XmlName('Set'),
                [XmlAttribute(XmlName('Aspect'), '100')],
              )
            ],
          ),
        );
      }
      newItem.children.add(enchantmentsNode);
    }

    setState(() {
      itemsNode.children.add(newItem);
    });
    _showSnackBar('Предмет добавлен', Colors.deepPurpleAccent);
  }

  void _removeItem(XmlElement itemNode) {
    setState(() {
      itemNode.remove();
    });
    _showSnackBar('Предмет удален', Colors.redAccent);
  }

    void _addEnchantment(XmlElement itemNode) {
    final List<String> perksList = (_allPerks.isNotEmpty)
        ? (List.of(_allPerks)..sort())
        : [
            'PERK_ITEM_SPECIAL_LIFESTEAL_WEAPON',
            'PERK_ABSORPTION',
            'PERK_REGENERATION',
            'PERK_TEMPEST',
            'PERK_BLEED',
            'PERK_STUN'
          ];

    String query = '';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = perksList.where((p) => p.toLowerCase().contains(query.toLowerCase())).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Выберите зачарование', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Поиск PERK_...',
                        prefixIcon: const Icon(Icons.search, color: Colors.amber),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF14141D),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => setDialogState(() => query = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Зачарования не найдены', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                              itemBuilder: (context, index) {
                                final perk = filtered[index];
                                return ListTile(
                                  hoverColor: Colors.amber.withOpacity(0.15),
                                  leading: const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                                  title: Text(perk, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _applyPerkToItem(itemNode, perk);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _applyPerkToItem(XmlElement itemNode, String rawPerkName) {
    var enchantmentsNode = itemNode.findElements('Enchantments').firstOrNull;
    if (enchantmentsNode == null) {
      enchantmentsNode = XmlElement(XmlName('Enchantments'));
      itemNode.children.add(enchantmentsNode);
    }

    final perkName = _formatPerkName(rawPerkName);
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
    _showSnackBar('Зачарование $perkName добавлено', Colors.amber.shade800);
  }

  void _showItemSelectionDialog() {
    String query = '';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = _tomlDatabase.values.where((item) {
              return item.name.toLowerCase().contains(query.toLowerCase()) ||
                  item.id.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Выберите предмет', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Поиск по предметам...',
                        prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF14141D),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => setDialogState(() => query = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  hoverColor: Colors.purple.withOpacity(0.15),
                                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(item.id, style: const TextStyle(color: Colors.purpleAccent, fontSize: 12)),
                                  onTap: () {
                                    _addItem(item.id);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTomlPanel() {
    final filteredToml = _tomlDatabase.values.where((item) {
      return item.name.toLowerCase().contains(_searchTomlQuery.toLowerCase()) ||
          item.id.toLowerCase().contains(_searchTomlQuery.toLowerCase());
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      const Icon(Icons.storage, color: Colors.purpleAccent, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'TOML База (${_tomlDatabase.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload_outlined, color: Colors.purpleAccent),
                  tooltip: 'Импортировать .toml файлы',
                  onPressed: _pickAndLoadToml,
                )
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Поиск в TOML...',
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF101016),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchTomlQuery = val),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredToml.isEmpty
                  ? const Center(child: Text('База пуста или ничего не найдено', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filteredToml.length,
                      itemBuilder: (context, index) {
                        final item = filteredToml[index];
                        return Card(
                          color: const Color(0xFF101017),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            dense: true,
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'ID: ${item.id}${item.enchantments.isNotEmpty ? '\nPerks: ${item.enchantments.join(', ')}' : ''}',
                              style: const TextStyle(color: Colors.purpleAccent, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.deepPurpleAccent, size: 22),
                              tooltip: 'Добавить в XML',
                              onPressed: () => _addItem(item.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXmlPanel() {
    final items = _getXmlItems();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      const Icon(Icons.code, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'XML Инвентарь (${items.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Предмет', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _showItemSelectionDialog,
                )
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Фильтр по инвентарю...',
                prefixIcon: const Icon(Icons.filter_list, size: 18, color: Colors.grey),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF101016),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchXmlQuery = val),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Нет предметов в сохранении', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final itemNode = items[index];
                        final id = itemNode.getAttribute('Name') ?? '';
                        final isEquipped = itemNode.getAttribute('Equipped') == '1';
                        final count = itemNode.getAttribute('Count') ?? '1';
                        final meta = _tomlDatabase[id];
                        final enchantments = itemNode
                            .findElements('Enchantments')
                            .firstOrNull
                            ?.findElements('Perk')
                            .toList();

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF12121A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: ExpansionTile(
                            shape: const Border(),
                            leading: Icon(
                              isEquipped ? Icons.shield : Icons.inventory_2_outlined,
                              color: isEquipped ? Colors.amber : Colors.grey,
                            ),
                            title: Text(meta?.name ?? id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(id, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                                if (isEquipped)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4)),
                                    child: const Text('EQUIPPED',
                                        style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text('x$count', style: const TextStyle(fontSize: 10)),
                                  backgroundColor: Colors.white.withOpacity(0.05),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _removeItem(itemNode),
                                ),
                              ],
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: const Color(0xFF0D0D12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (enchantments != null && enchantments.isNotEmpty) ...[
                                      const Text('Зачарования (PERK_):',
                                          style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      ...enchantments.map((perk) {
                                        final perkName = perk.getAttribute('Name') ?? '';
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.amber.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  perkName,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.amberAccent),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.flash_on, size: 16, color: Colors.amber),
                                        label: const Text('Зачаровать', style: TextStyle(color: Colors.amber, fontSize: 12)),
                                        onPressed: () => _addEnchantment(itemNode),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF14141C),
          elevation: 2,
          title: Row(
            children: [
              const Icon(Icons.blur_on, color: Colors.deepPurpleAccent, size: 24),
              const SizedBox(width: 8),
              const Text('Saturn Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(_currentFileName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_open, color: Colors.purpleAccent),
              tooltip: 'Открыть XML',
              onPressed: _pickAndLoadXml,
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.deepPurpleAccent),
              tooltip: 'Экспорт XML',
              onPressed: _downloadXml,
            ),
            const SizedBox(width: 8),
          ],
          bottom: isMobile
              ? const TabBar(
                  indicatorColor: Colors.deepPurpleAccent,
                  tabs: [
                    Tab(icon: Icon(Icons.storage, size: 20), text: 'TOML База'),
                    Tab(icon: Icon(Icons.code, size: 20), text: 'XML Инвентарь'),
                  ],
                )
              : null,
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: isMobile
              ? TabBarView(
                  children: [
                    _buildTomlPanel(),
                    _buildXmlPanel(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 2, child: _buildTomlPanel()),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: _buildXmlPanel()),
                  ],
                ),
        ),
      ),
    );
  }
}
