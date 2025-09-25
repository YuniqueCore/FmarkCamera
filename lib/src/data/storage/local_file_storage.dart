import 'package:fmark_camera/src/data/storage/local_file_storage_io.dart'
    if (dart.library.html) 'package:fmark_camera/src/data/storage/local_file_storage_web.dart'
    as impl;

abstract class LocalFileStorage {
  const LocalFileStorage();

  Future<Map<String, dynamic>> readJson(String fileName);
  Future<void> writeJson(String fileName, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> readJsonList(String fileName);
  Future<void> writeJsonList(String fileName, List<Map<String, dynamic>> items);

  factory LocalFileStorage.create() => impl.createLocalFileStorage();
}
