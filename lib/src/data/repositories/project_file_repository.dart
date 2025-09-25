import 'dart:async';

import 'package:fmark_camera/src/domain/models/watermark_project.dart';
import 'package:fmark_camera/src/domain/repositories/project_repository.dart';
import 'package:fmark_camera/src/data/storage/local_file_storage.dart';

class ProjectFileRepository implements ProjectRepository {
  ProjectFileRepository(this.storage);

  static const String _fileName = 'watermark_projects.json';
  final LocalFileStorage storage;
  List<WatermarkProject>? _cache;

  @override
  Future<List<WatermarkProject>> loadProjects() async {
    if (_cache != null) {
      return _cache!;
    }
    final list = await storage.readJsonList(_fileName);
    _cache = list.map(WatermarkProject.fromJson).toList();
    return _cache!;
  }

  @override
  Future<void> saveProjects(List<WatermarkProject> projects) async {
    _cache = projects;
    await storage.writeJsonList(
      _fileName,
      projects.map((project) => project.toJson()).toList(),
    );
  }
}
