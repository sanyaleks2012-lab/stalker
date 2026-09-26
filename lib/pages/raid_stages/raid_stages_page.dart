import 'package:flutter/material.dart';
import 'package:saturn/logic/raid_stages.dart';
import 'package:saturn/shizuku_api.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RaidStagesPage extends StatefulWidget {
  const RaidStagesPage({super.key});

  @override
  State<RaidStagesPage> createState() => _RaidStagesPageState();
}

class _RaidStagesPageState extends State<RaidStagesPage> {
  bool _isInitialized = false;
  String _status = 'Not loaded';
  List<XmlElement> _zones = [];
  XmlElement? _selectedZone;
  XmlElement? _selectedBattle;
  XmlElement? _selectedWarrior;
  XmlElement? _selectedFight;
  XmlElement? _selectedRules;
  int _undoStackPos = 0;
  final List<XmlDocument> _undoStack = [];
  static const int MAX_UNDO = 30;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await RaidStagesManager.loadRaidStagesXml();
      _zones = RaidStagesManager.getZones();
      _status = 'Loaded successfully';
      _isInitialized = true;
      setState(() {});
    } catch (e) {
      _status = 'Error: $e';
      _isInitialized = false;
      setState(() {});
    }
  }

  void _saveState() {
    if (RaidStagesManager._xmlDocument != null) {
      _undoStack.add(RaidStagesManager._xmlDocument!);
      if (_undoStack.length > MAX_UNDO) {
        _undoStack.removeAt(0);
      } else {
        _undoStackPos++;
      }
    }
  }

  void _undo() {
    if (_undoStackPos <= 0) {
      Fluttertoast.showToast(msg: "No more actions to undo");
      return;
    }
    
    _undoStackPos--;
    setState(() {
      RaidStagesManager._xmlDocument = _undoStack[_undoStackPos];
      RaidStagesManager._root = RaidStagesManager._xmlDocument!.findAllElements("Root").first;
      _zones = RaidStagesManager.getZones();
    });
    
    Fluttertoast.showToast(msg: "Undo successful");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raid Stages Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _undo,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: () => RaidStagesManager.saveRaidStagesXml(),
          ),
        ],
      ),
      body: _isInitialized
          ? _buildMainMenu()
          : Center(
              child: Text('Status: $_status\nTap to retry'),
            ),
    );
  }

  Widget _buildMainMenu() {
    return ListView(
      children: [
        ListTile(
          title: const Text('Zones and Bosses'),
          leading: const Icon(Icons.home),
          onTap: () => _navigateToZoneMenu(context),
        ),
        ListTile(
          title: const Text('Search Boss'),
          leading: const Icon(Icons.search),
          onTap: () => _showSearchDialog(context),
        ),
        ListTile(
          title: const Text('Create Zone'),
          leading: const Icon(Icons.add),
          onTap: () => _showCreateZoneDialog(context),
        ),
        ListTile(
          title: const Text('Check XML'),
          leading: const Icon(Icons.code),
          onTap: () => _showXmlDialog(context),
        ),
        ListTile(
          title: Text('Undo: $_undoStackPos/${_undoStack.length}'),
          leading: const Icon(Icons.undo),
          onTap: _undo,
        ),
        ListTile(
          title: const Text('Save + Backup'),
          leading: const Icon(Icons.save),
          onTap: () => RaidStagesManager.saveRaidStagesXml(),
        ),
        ListTile(
          title: const Text('About'),
          leading: const Icon(Icons.info),
          onTap: () => _showAboutDialog(context),
        ),
        ListTile(
          title: const Text('Exit'),
          leading: const Icon(Icons.exit_to_app),
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  void _navigateToZoneMenu(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZoneMenuPage(
          onZoneSelected: (zone) => setState(() {
            _selectedZone = zone;
            _selectedBattle = null;
            _selectedWarrior = null;
            _selectedFight = null;
            _selectedRules = null;
          }),
          onZoneChanged: () => setState(() {
            _zones = RaidStagesManager.getZones();
          }),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SearchBossDialog(
        onBossSelected: (battle) => setState(() {
          _selectedBattle = battle;
          // Find parent zone
          final parent = battle.parent;
          if (parent != null && parent is XmlElement) {
            _selectedZone = parent;
            // Find warrior and fight
            _selectedWarrior = battle.findAllElements("Warrior").firstOrNull;
            _selectedFight = battle.findAllElements("Fight").firstOrNull;
            _selectedRules = battle.findAllElements("Rules").firstOrNull;
          }
        }),
      ),
    );
  }

  void _showCreateZoneDialog(BuildContext context) {
    String name = '';
    String fileName = '';
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Zone Name'),
              onChanged: (value) => name = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'File Name'),
              onChanged: (value) => fileName = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty && fileName.isNotEmpty) {
                _saveState();
                RaidStagesManager.createZone(name: name, fileName: fileName);
                setState(() {
                  _zones = RaidStagesManager.getZones();
                });
                Navigator.of(context).pop();
                Fluttertoast.showToast(msg: 'Zone created');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showXmlDialog(BuildContext context) {
    if (RaidStagesManager._xmlDocument == null) return;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('XML Content'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              RaidStagesManager._xmlDocument!.toXmlString(pretty: true),
              style: const FontFamily('monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AboutDialog(
        applicationName: 'Raid Stages Editor',
        applicationVersion: '1.0.0',
        applicationIcon: const Icon(Icons.gamepad),
        children: const [
          Text('Port of sf2_raid_v4.py to Flutter'),
          Text('For editing Shadow Fight 2 raid stages'),
        ],
      ),
    );
  }
}

class ZoneMenuPage extends StatefulWidget {
  final Function(XmlElement) onZoneSelected;
  final Function() onZoneChanged;

  const ZoneMenuPage({
    super.key,
    required this.onZoneSelected,
    required this.onZoneChanged,
  });

  @override
  State<ZoneMenuPage> createState() => _ZoneMenuPageState();
}

class _ZoneMenuPageState extends State<ZoneMenuPage> {
  late List<XmlElement> _zones;

  @override
  void initState() {
    super.initState();
    _zones = RaidStagesManager.getZones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zones Menu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _zones.isEmpty
          ? const Center(child: Text('No zones available'))
          : ListView(
              children: [
                for (int i = 0; i < _zones.length; i++)
                  ListTile(
                    title: Text('${_zones[i].getAttribute('Name')}'),
                    subtitle: Text('File: ${_zones[i].getAttribute('FileName')}'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      widget.onZoneSelected(_zones[i]);
                      Navigator.of(context).pop();
                    },
                  ),
                const Divider(),
                ListTile(
                  title: const Text('Create New Zone'),
                  leading: const Icon(Icons.add),
                  onTap: () => _showCreateZoneDialog(context),
                ),
              ],
            ),
    );
  }

  void _showCreateZoneDialog(BuildContext context) {
    String name = '';
    String fileName = '';
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Zone Name'),
              onChanged: (value) => name = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'File Name'),
              onChanged: (value) => fileName = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty && fileName.isNotEmpty) {
                RaidStagesManager.createZone(name: name, fileName: fileName);
                widget.onZoneChanged();
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to main menu
                Fluttertoast.showToast(msg: 'Zone created');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class SearchBossDialog extends StatefulWidget {
  final Function(XmlElement) onBossSelected;

  const SearchBossDialog({
    super.key,
    required this.onBossSelected,
  });

  @override
  State<SearchBossDialog> createState() => _SearchBossDialogState();
}

class _SearchBossDialogState extends State<SearchBossDialog> {
  String _query = '';
  List<XmlElement> _matches = [];
  bool _isSearching = false;

  void _search() {
    if (_query.isEmpty) {
      setState(() {
        _matches = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    
    final q = _query.toLowerCase();
    final List<XmlElement> matches = [];
    
    for (final zone in RaidStagesManager.getZones()) {
      for (final battle in RaidStagesManager.getBattles(zone)) {
        final warrior = battle.findAllElements("Warrior").firstOrNull;
        
        final values = [
          battle.getAttribute('Name') ?? '',
          battle.getAttribute('Alias') ?? '',
          battle.getAttribute('Title') ?? '',
          battle.getAttribute('Location') ?? '',
        ];
        
        if (warrior != null) {
          values.addAll([
            warrior.getAttribute('Template') ?? '',
            warrior.getAttribute('Tactic') ?? '',
          ]);
        }
        
        if (values.any((value) => value.toLowerCase().contains(q))) {
          matches.add(battle);
        }
      }
    }
    
    setState(() {
      _matches = matches;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search Boss'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search query',
              suffixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() => _query = value);
            },
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 16),
          _isSearching
              ? const SizedBox(
                  height: 24,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _matches.isEmpty
                  ? const Text('No matches found')
                  : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _matches.length,
                        itemBuilder: (context, index) {
                          final battle = _matches[index];
                          final zoneName = battle.parent?.getAttribute('Name') ?? 'Unknown';
                          return ListTile(
                            title: Text(battle.getAttribute('Name') ?? 'Unknown'),
                            subtitle: Text('Zone: $zoneName'),
                            onTap: () {
                              widget.onBossSelected(battle);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }
}