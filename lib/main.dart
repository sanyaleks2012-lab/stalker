import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:log_plus/log_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:saturn/app.dart';
import 'package:saturn/logic/enchantment.dart';
import 'package:saturn/logic/item_database.dart';
import 'package:saturn/logic/records_manager.dart';
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
    _initializeApp();
  }

  Future<void> _requestStoragePermissions() async {
    if (await Permission.manageExternalStorage.isGranted) {
      return;
    }

    var status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _requestStoragePermissions();

      await EnchantmentsManager.loadFromFiles();
      logger.i("Loaded enchantment TOMLs");

      await ItemDatabase.load();
      logger.i("Loaded item database");

      final traits = await ItemDatabase.loadTraits();
      ItemDatabase.traits = traits.toList();
      logger.i("Loaded item traits");

      await RecordsManager.loadRecords();
      logger.i("Loaded saves from /sdcard/AddNew/saves");
    } catch (e, stackTrace) {
      logger.e("Error initializing app: $e\n$stackTrace");
    }
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
