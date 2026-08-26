import 'dart:math';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:log_plus/log_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:detool64/app.dart';
import 'package:detool64/logic/item_database.dart';
import 'package:detool64/logic/enchantment.dart';
import 'package:detool64/themes.dart';

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
  static const List<String> demons = [
    'shogun',
    'wasp',
    'lynx',
    'widow',
    'hermit',
    'butcher',
    'titan',
  ];

  static final Random _random = Random();

  void _logDemonEvent() {
    if (_random.nextDouble() < 0.15) {
      final demon = demons[_random.nextInt(demons.length)];
      final attitude = _random.nextBool() ? 'respect' : 'hate';
      logger.i("nice u get $attitude from $demon");
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }

    try {
      await ItemDatabase.load();
      logger.i("Loaded item database");
      _logDemonEvent();

      final traits = await ItemDatabase.loadTraits();
      ItemDatabase.traits = traits.toList();
      logger.i("Loaded item traits");
      _logDemonEvent();

      await EnchantmentsManager.loadFromFiles();
      logger.i("Loaded enchantments from /sdcard/AddNew");
      _logDemonEvent();
    } catch (e, stack) {
      logger.e("Failed to initialize app data: $e", stackTrace: stack);
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
              title: "DETool64",
              home: const App());
        });
      },
    );
  }
}
