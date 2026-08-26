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