import 'dart:io';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
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

    dataFile.create();
    dataFile.writeAsString(xml);

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

  static Future<Directory> _getRecordsDirectory() async {
    final externalStorage = (await getExternalStorageDirectory())!;
    final recordsDirectory = Directory("${externalStorage.path}/records");

    await recordsDirectory.create(recursive: true);
    return recordsDirectory;
  }

  static Future<List<Record>> loadRecords() async {
    final recordsDirectory = await _getRecordsDirectory();

    List<Record> records = [];

    for (final folder in recordsDirectory.listSync().whereType<Directory>()) {
      final record = await loadRecord(folder.path);
      records.add(record);
    }

    return records;
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
      BridgeApi.runCommand("cp $userdataPath/users.xml $path/data.xml");
    }

    final tree = XmlDocument.parse(await readFile(dataPath));
    return Record(tree, metadata);
  }

  static Future<void> _updateRecordsMetadata() async {
    final directory = await _getRecordsDirectory();

    for (final record in records) {
      final metadataFile =
          File("${directory.path}/${record.metadata.uuid}/metadata.toml");
      await metadataFile.create();
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
