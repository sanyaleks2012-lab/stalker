import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:saturn/shizuku_api.dart';

Future<String> readFile(String path) async {
  final Directory directory = (await getExternalStorageDirectory())!;
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = makeTempFile(directory.path);

  final cpOutput = await BridgeApi.runCommand("cp $path ${file.path}");
  validateCpOutput(path, cpOutput);

  if (!await file.exists()) {
    throw FileSystemException('Failed to copy file via Shizuku', path);
  }

  final contents = await file.readAsString();
  await file.delete().catchError((_) async => File(file.path));
  await BridgeApi.runCommand("rm ${file.path}");

  return contents;
}

String validateCpOutput(String path, String? output) {
  if (output == null) {
    return '';
  }

  if (output.contains('No such file or directory')) {
    throw FileSystemException('File does not exist', path);
  } else if (output.contains('Permission denied')) {
    throw FileSystemException('Permission denied', path);
  } else if (output.contains('Is a directory')) {
    throw FileSystemException('Path is a directory, not a file', path);
  }

  return output;
}

File makeTempFile(String path) {
  final rnd = List.generate(
      10,
      (_) => 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[
          Random().nextInt(62)]).join();
  return File("$path/.temp$rnd");
}

Future<void> writeFile(String targetPath, String contents) async {
  final directory = (await getExternalStorageDirectory())!;
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = makeTempFile(directory.path);
  await file.writeAsString(contents);
  final cpOutput = await BridgeApi.runCommand("cp ${file.path} $targetPath");
  validateCpOutput(targetPath, cpOutput);
  await file.delete().catchError((_) async => File(file.path));
  await BridgeApi.runCommand("rm ${file.path}");
}
