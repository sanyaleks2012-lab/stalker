![Saturn Banner](img/barrier.png)

# Saturn – Shadow Fight 2 Save Viewer & Modifier

**Saturn** is an Android utility application (a fork of [Stalker](https://github.com/onerdna/stalker)) designed to **view and optionally modify save files** for the mobile game **Shadow Fight 2** (including support for **Shadow Fight 2: Definitive Edition 64** by seby7113).

> ⚠️ **Disclaimer:** Shadow Fight 2 is a trademark of **Nekki Limited**. This application is not affiliated with, endorsed by, or associated with Nekki, Banzai Games, or the developers of Shadow Fight 2 in any way. Use of this application is at your own risk. You are solely responsible for ensuring your use complies with Nekki’s terms of service and any applicable laws.

---

## 🔍 What It Does

Saturn allows users to inspect and optionally tweak various aspects of their Shadow Fight 2 game progress by interacting with local save files.

### 🔧 Features

- **View and modify**:
  - Coins
  - Gems
  - Forge materials
- **Enable**:
  - Unlimited energy
  - Dojo disciple
- **Inventory Management**:
  - Add or remove weapons, armor, helmets, and ranged gear
  - Apply enchantments to equipment (Simple, Medium, Mythical)
- **Open TOML Enchantment Lists Editor**:
  - Customize and add new enchantments via TOML files on external storage.
- **Save records (slots)**:
  - Manage progress with separate records — load and save them at any time, stored directly on external storage for easy backup and management.

> ⚠️ Modifying save files can impact gameplay and may violate the game’s terms of use. Use modification features at your own risk.

---

## ⚙️ External Storage & Custom TOML Enchantments

Saturn features an open system for enchantment lists using **TOML** configurations, as well as external storage for save records.

### 📜 TOML Enchantment Lists (`/sdcard/AddNew/perk`)
The app automatically extracts and manages enchantment TOML files inside your device's external storage directory:
`/sdcard/AddNew/perk/`

You can edit these `.toml` files directly to customize or add new enchantment properties.

**If the `/sdcard/AddNew/perk` directory is empty or missing, check the following:**
1. **First Launch:** The app generates these files automatically on start. Make sure you have launched the application at least once.
2. **Storage Permissions:** Ensure Saturn has been granted permission to write to external storage (Storage / All Files Access permissions).

### 💾 Save Records
Save slots and backups created within Saturn are also stored directly on external storage, allowing for effortless manual extraction, backup, or transfer across devices.

---

## ❗ How to Install & Set Up

1. Download and install the APK file from the **Releases** page.
2. Install and configure [Shizuku](https://shizuku.rikka.app/).
3. Start the Shizuku service if it is not already running.
4. Launch **Saturn** and grant the required Shizuku and Storage permissions.
5. Proceed to the additional setup step:
   - Ensure the game is completely closed.
   - Minimize Saturn (do **not** fully close it).
   - Launch Shadow Fight 2 and wait until it fully loads into the main menu.
   - Close the game completely.
   - Return to Saturn and tap the **Reinitialize** button.

### ❗ Usage Rules
- **Always close the game completely** before making changes in the app.
- Tap **Save** after making edits for them to take effect.

---

## ❓ FAQ

- **Will there ever be an iOS version?**
  - No.
- **Why does the app use Shizuku?**
  - Shizuku is required to access internal game save files that are protected by Android system permissions, as well as to execute the setup service binary.
- **Can you add verified gems, raid consumables, or a damage hack?**
  - No.
- **What does the setup service actually do?**
  - The setup service’s only purpose is to modify your user ID inside the game’s runtime process. It automatically terminates once completed (or after 2 minutes of inactivity). The user ID is a random device-specific string containing no personal data.

---

## 🔧 Troubleshooting

- **Tapping 'Reinitialize' does nothing:**
  1. Re-check the setup instructions step-by-step.
  2. Increase the **Logger buffer size** in Developer Options from 256K to 8M.
  3. On Huawei/Honor devices, manually enable **Logcat** in system settings.
  4. If the issue persists, open a bug report on the repository's Issues page.

---

## 🎨 Attributions & Credits

### 👥 Authors & Maintainers
- **Original Stalker Author:** [Andreno](https://www.reddit.com/user/XAndrenoX/)
- **Original Repository:** [onerdna/stalker](https://github.com/onerdna/stalker)
- **SF2: Definitive Edition 64 Mod Author:** [seby7113](https://www.reddit.com/user/seby7113)

### ❤ Special Thanks
- [**Shizuku**](https://shizuku.rikka.app/)
- **ShadowFight2dojo Community** ([Reddit](https://www.reddit.com/r/ShadowFight2dojo/) | [Discord](https://discord.gg/ThDBZztuJu))

### 🖼️ Icons Attributions
- Sword, Katana, Shuriken, Amulet, Armor, Knight, Dojo, Forge, Virus, Treasure, Weapon, Home, Document, Wrench icons sourced from [Flaticon](https://www.flaticon.com/) (Iconic Panda, Vectors Market, Roman Káčerek, juicy_fish, Good Ware, Freepik, Nikita Golubev, kliwir art, Smashicons).

---

## 📜 License

By downloading or using this software, you agree to the terms outlined in the [LICENSE](./LICENSE).
