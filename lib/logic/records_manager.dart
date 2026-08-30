import 'dart:io';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:saturn/logic/record.dart';
import 'package:saturn/main.dart';
import 'package:saturn/shizuku_api.dart';
import 'package:saturn/shizuku_file.dart';
import 'package:toml/toml.dart';
import 'package:xml/xml.dart';

class RecordsManager {
  static List<Record> records = [];
  static const userdataPath =
      "/sdcard/Android/data/com.sf2.de/files/userdata";
  static const externalSavesPath = "/sdcard/AddNew/saves";

  static Record? get activeRecord =>
      records.where((e) => e.metadata.isActive == true).firstOrNull;

  static set activeRecord(Record? record) {
    for (var e in records) {
      e.metadata.isActive = false;
    }
    record?.metadata.isActive = true;
    try {
      _updateRecordsMetadata();
    } catch (e) {
      logger.e("updateRecordsMetadata: $e");
    }
  }

  static Future<Directory> _getRecordsDirectory() async {
    final recordsDirectory = Directory(externalSavesPath);
    if (!await recordsDirectory.exists()) {
      await recordsDirectory.create(recursive: true);
    }
    return recordsDirectory;
  }

  static Future<void> saveRecord(Record record) async {
    final recordsDirectory = await _getRecordsDirectory();

    final metadataFile =
        File("${recordsDirectory.path}/${record.metadata.uuid}/metadata.toml");
    await metadataFile.create(recursive: true);

    metadataFile.writeAsString(
        TomlDocument.fromMap(record.metadata.toMap()).toString());

    final dataFile =
        File("${recordsDirectory.path}/${record.metadata.uuid}/data.xml");
    final xml = record.xml;

    await dataFile.create(recursive: true);
    await dataFile.writeAsString(xml);

    if (activeRecord == record) {
      await writeFile("$userdataPath/users.xml", xml);
      await writeFile("$userdataPath/users_backup.xml", xml);
    }
  }

  static void saveRecordWithToast(Record record) {
    saveRecord(record).then((result) {
      Fluttertoast.showToast(msg: "Saved successfully");
    }).onError((e, _) {
      Fluttertoast.showToast(msg: "Error occured while saving: $e");
    });
  }

  static String formatXml(String xml) {
    final reNewlines = RegExp(r'\n\s*');
    final noNewlines = xml.replaceAll(reNewlines, '');

    final reXmlDecl = RegExp(r'(<\?xml[^>]+\?>)\s*');
    final formatted =
        noNewlines.replaceAllMapped(reXmlDecl, (match) => match.group(1)!);

    return formatted;
  }

  static Future<List<Record>> loadRecords() async {
    final recordsDirectory = await _getRecordsDirectory();
    List<Directory> folders = recordsDirectory.listSync().whereType<Directory>().toList();

    // Если в папке /sdcard/AddNew/saves пусто — клонируем существующий сейв из userdata
    if (folders.isEmpty) {
      logger.i("Saves directory is empty. Cloning default save from userdata...");
      await _cloneDefaultUserdataSave(recordsDirectory.path);
      folders = recordsDirectory.listSync().whereType<Directory>().toList();
    }

    List<Record> loadedRecords = [];
    for (final folder in folders) {
      try {
        final record = await loadRecord(folder.path);
        loadedRecords.add(record);
      } catch (e) {
        logger.e("Failed to load record from ${folder.path}: $e");
      }
    }

    records = loadedRecords;
    return records;
  }

  static Future<void> _cloneDefaultUserdataSave(String baseSavesPath) async {
    final defaultUuid = "default_save";
    final defaultFolder = Directory("$baseSavesPath/$defaultUuid");
    await defaultFolder.create(recursive: true);

    // Копируем файл users.xml через Shizuku/BridgeApi если есть
    try {
      await BridgeApi.runCommand("cp $userdataPath/users.xml ${defaultFolder.path}/data.xml");
    } catch (_) {
      // Фолбэк чтение/запись
      final content = await readFile("$userdataPath/users.xml");
      final dataFile = File("${defaultFolder.path}/data.xml");
      await dataFile.writeAsString(content);
    }

    // Создаем метаданные для нового дефолтного профиля
    final metadata = RecordMetadata("Default Save", defaultUuid, true);
    final metadataFile = File("${defaultFolder.path}/metadata.toml");
    await metadataFile.writeAsString(TomlDocument.fromMap(metadata.toMap()).toString());
  }

  static Future<RecordMetadata> _loadRecordMetadata(String path) async {
    final metadataFile = File("$path/metadata.toml");
    return RecordMetadata.fromMap(
        TomlDocument.parse(await metadataFile.readAsString()).toMap());
  }

  static Future<Record> loadRecord(String path) async {
    final metadata = await _loadRecordMetadata(path);

    final dataPath =
        metadata.isActive ? "$userdataPath/users.xml" : "$path/data.xml";
    if (metadata.isActive) {
      try {
        await BridgeApi.runCommand("cp $userdataPath/users.xml $path/data.xml");
      } catch (e) {
        logger.e("Shizuku cp failed: $e");
      }
    }

    final tree = XmlDocument.parse(await readFile(dataPath));
    return Record(tree, metadata);
  }

  static Future<void> _updateRecordsMetadata() async {
    final directory = await _getRecordsDirectory();

    for (final record in records) {
      final metadataFile =
          File("${directory.path}/${record.metadata.uuid}/metadata.toml");
      await metadataFile.create(recursive: true);
      await metadataFile.writeAsString(
          TomlDocument.fromMap(record.metadata.toMap()).toString());
    }
  }

  static Future<void> deleteRecord(Record record) async {
    final directory = await _getRecordsDirectory();
    await Directory("${directory.path}/${record.metadata.uuid}")
        .delete(recursive: true);
  }
}
