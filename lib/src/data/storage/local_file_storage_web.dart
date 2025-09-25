import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:fmark_camera/src/data/storage/local_file_storage.dart';

class WebLocalFileStorage implements LocalFileStorage {
  const WebLocalFileStorage();

  String _key(String fileName) => 'fmark_storage/$fileName';

  @override
  Future<Map<String, dynamic>> readJson(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_key(fileName));
    if (content == null || content.isEmpty) {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(fileName), jsonEncode(data));
  }

  @override
  Future<List<Map<String, dynamic>>> readJsonList(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_key(fileName));
    if (content == null || content.isEmpty) {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(fileName), jsonEncode(items));
  }
}

LocalFileStorage createLocalFileStorage() => const WebLocalFileStorage();
