import 'package:flutter/foundation.dart';

import 'package:fmark_camera/src/domain/models/watermark_project.dart';
import 'package:fmark_camera/src/domain/repositories/project_repository.dart';

class WatermarkProjectsController extends ChangeNotifier {
  WatermarkProjectsController({required this.repository});

  final ProjectRepository repository;

  List<WatermarkProject> _projects = const <WatermarkProject>[];

  List<WatermarkProject> get projects => _projects;

  Future<void> load() async {
    final loaded = await repository.loadProjects();
    _projects = [...loaded]
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    notifyListeners();
  }

  Future<void> addProject(WatermarkProject project) async {
    _projects = [project, ..._projects]
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    await repository.saveProjects(_projects);
    notifyListeners();
  }

  Future<void> updateProject(WatermarkProject project) async {
    _projects = _projects
        .map((item) => item.id == project.id ? project : item)
        .toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    await repository.saveProjects(_projects);
    notifyListeners();
  }

  Future<void> removeProject(String projectId) async {
    _projects = _projects.where((item) => item.id != projectId).toList();
    await repository.saveProjects(_projects);
    notifyListeners();
  }
}
