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
