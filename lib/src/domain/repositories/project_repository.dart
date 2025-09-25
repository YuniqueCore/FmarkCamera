import 'package:fmark_camera/src/domain/models/watermark_project.dart';

abstract class ProjectRepository {
  Future<List<WatermarkProject>> loadProjects();

  Future<void> saveProjects(List<WatermarkProject> projects);
}
