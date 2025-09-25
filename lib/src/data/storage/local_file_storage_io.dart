import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:fmark_camera/src/data/storage/local_file_storage.dart';

class IoLocalFileStorage implements LocalFileStorage {
  const IoLocalFileStorage();

  Future<File> _resolve(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  @override
  Future<Map<String, dynamic>> readJson(String fileName) async {
    final file = await _resolve(fileName);
    final content = await file.readAsString();
    if (content.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  @override
  Future<void> writeJson(String fileName, Map<String, dynamic> data) async {
    final file = await _resolve(fileName);
    await file.writeAsString(jsonEncode(data));
  }

  @override
  Future<List<Map<String, dynamic>>> readJsonList(String fileName) async {
    final file = await _resolve(fileName);
    final content = await file.readAsString();
    if (content.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.map((item) => item as Map<String, dynamic>).toList();
      }
      return <Map<String, dynamic>>[];
    } on FormatException {
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Future<void> writeJsonList(
      String fileName, List<Map<String, dynamic>> items) async {
    final file = await _resolve(fileName);
    await file.writeAsString(jsonEncode(items));
  }
}

LocalFileStorage createLocalFileStorage() => const IoLocalFileStorage();
