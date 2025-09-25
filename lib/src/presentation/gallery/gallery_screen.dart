import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/domain/models/watermark_project.dart';
import 'package:fmark_camera/src/domain/repositories/project_repository.dart';
import 'package:fmark_camera/src/domain/repositories/watermark_profile_repository.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/watermark_context_controller.dart';
import 'package:fmark_camera/src/services/watermark_exporter.dart';
import 'package:fmark_camera/src/services/watermark_renderer.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.bootstrapper});

  static const String routeName = '/gallery';
  final Bootstrapper bootstrapper;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final ProjectRepository _projectRepository;
  late final WatermarkProfileRepository _profileRepository;
  late final WatermarkRenderer _renderer;
  late final WatermarkExporter _exporter;
  late final WatermarkContextController _contextController;
  List<WatermarkProject> _projects = const <WatermarkProject>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _projectRepository = widget.bootstrapper.projectRepository;
    _profileRepository = widget.bootstrapper.profileRepository;
    _renderer = widget.bootstrapper.renderer;
    _exporter = widget.bootstrapper.exporter;
    _contextController = widget.bootstrapper.contextController;
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await _projectRepository.loadProjects();
    setState(() {
      _projects = projects.reversed.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('拍摄记录')),
      body: _projects.isEmpty
          ? const Center(child: Text('暂无拍摄记录'))
          : ListView.builder(
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                return _ProjectCard(
                  project: project,
                  onExport: () => _exportProject(project),
                  onUpdateOverlay: () => _refreshOverlay(project),
                );
              },
            ),
    );
  }

  Future<void> _refreshOverlay(WatermarkProject project) async {
    final profiles = await _profileRepository.loadProfiles();
    final profile = profiles.firstWhere((item) => item.id == project.profileId,
        orElse: () => profiles.first);
    final previewSize = const Size(1080, 1920);
    final bytes = await _renderer.renderToBytes(
      profile: profile,
      context: _contextController.context,
      canvasSize: previewSize,
    );
    final overlayFile = await _exporter.saveOverlayBytes(bytes);
    final updated = project.copyWith(overlayPath: overlayFile.path);
    final updatedProjects = _projects
        .map((item) => item.id == project.id ? updated : item)
        .toList();
    await _projectRepository.saveProjects(updatedProjects.reversed.toList());
    setState(() => _projects = updatedProjects);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('水印已更新')));
    }
  }

  Future<void> _exportProject(WatermarkProject project) async {
    if (project.overlayPath == null) {
      await _refreshOverlay(project);
    }
    final overlay = project.overlayPath;
    if (overlay == null) {
      return;
    }
    String? resultPath;
    if (project.mediaType == WatermarkMediaType.photo) {
      resultPath = await _exporter.composePhoto(
          photoPath: project.mediaPath, overlayPath: overlay);
    } else {
      resultPath = await _exporter.composeVideo(
          videoPath: project.mediaPath, overlayPath: overlay);
    }
    if (!mounted) {
      return;
    }
    if (resultPath == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('导出失败，请稍后重试')));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('导出成功：$resultPath')));
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onExport,
    required this.onUpdateOverlay,
  });

  final WatermarkProject project;
  final VoidCallback onExport;
  final VoidCallback onUpdateOverlay;

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(project.mediaPath);
    final subtitle =
        '${project.mediaType.name.toUpperCase()}  ·  ${project.capturedAt}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(project.mediaType == WatermarkMediaType.photo
            ? Icons.photo_camera
            : Icons.videocam),
        title: Text(fileName),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'export':
                onExport();
                break;
              case 'update':
                onUpdateOverlay();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'export', child: Text('导出带水印文件')),
            const PopupMenuItem(value: 'update', child: Text('根据当前模板更新水印')),
          ],
        ),
      ),
    );
  }
}
