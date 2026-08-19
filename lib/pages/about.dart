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
                      "DETool64",
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
