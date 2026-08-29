import 'package:flutter/material.dart';

void main() {
  runApp(const SaturnWebApp());
}

class SaturnWebApp extends StatelessWidget {
  const SaturnWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saturn Web',
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

class WebHomePage extends StatelessWidget {
  const WebHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saturn Web Panel'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.web,
              size: 64,
              color: Colors.deepPurpleAccent,
            ),
            const SizedBox(height: 16),
            Text(
              'Saturn Web Online',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Отдельный модуль сайта успешно запущен.'),
          ],
        ),
      ),
    );
  }
}
