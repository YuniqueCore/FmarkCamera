import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/domain/models/watermark_project.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/watermark_context_controller.dart';
import 'package:fmark_camera/src/services/watermark_exporter.dart';
import 'package:fmark_camera/src/services/watermark_profiles_controller.dart';
import 'package:fmark_camera/src/services/watermark_projects_controller.dart';
import 'package:fmark_camera/src/services/watermark_renderer.dart';
import 'package:fmark_camera/src/presentation/profiles/profile_editor_screen.dart';
import 'package:fmark_camera/src/presentation/widgets/watermark_canvas.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.bootstrapper});

  static const String routeName = '/gallery';

  final Bootstrapper bootstrapper;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final WatermarkProjectsController _projectsController;
  late final WatermarkProfilesController _profilesController;
  late final WatermarkContextController _contextController;

  @override
  void initState() {
    super.initState();
    final bootstrapper = widget.bootstrapper;
    _projectsController = bootstrapper.projectsController;
    _profilesController = bootstrapper.profilesController;
    _contextController = bootstrapper.contextController;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _projectsController,
      builder: (context, _) {
        final projects = _projectsController.projects;
        if (projects.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('拍摄图库')),
            body: const Center(child: Text('暂无拍摄记录')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('拍摄图库')),
          body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final profile = _profilesController.profiles.firstWhere(
                (item) => item.id == project.profileId,
                orElse: () => _profilesController.profiles.first,
              );
              return GestureDetector(
                onTap: () => _openDetail(project, profile),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildMediaPreview(project),
                        Positioned.fill(
                          child: WatermarkCanvasView(
                            elements: profile.elements,
                            contextData: _contextController.context,
                            canvasSize: project.canvasSize ??
                                profile.canvasSize ??
                                const WatermarkCanvasSize(
                                    width: 1080, height: 1920),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  project.mediaType == WatermarkMediaType.photo
                                      ? '照片'
                                      : '视频',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  DateFormat('yyyy-MM-dd HH:mm')
                                      .format(project.capturedAt),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMediaPreview(WatermarkProject project) {
    if (project.mediaType == WatermarkMediaType.photo && !kIsWeb) {
      final file = File(project.mediaPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Icon(
        project.mediaType == WatermarkMediaType.photo
            ? Icons.image_outlined
            : Icons.videocam_outlined,
        color: Colors.white30,
        size: 48,
      ),
    );
  }

  void _openDetail(WatermarkProject project, WatermarkProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CaptureDetailPage(
          project: project,
          initialProfile: profile,
          bootstrapper: widget.bootstrapper,
          onProjectUpdated: (updated) async {
            await _projectsController.updateProject(updated);
          },
        ),
      ),
    );
  }
}

class _CaptureDetailPage extends StatefulWidget {
  const _CaptureDetailPage({
    required this.project,
    required this.initialProfile,
    required this.bootstrapper,
    required this.onProjectUpdated,
  });

  final WatermarkProject project;
  final WatermarkProfile initialProfile;
  final Bootstrapper bootstrapper;
  final Future<void> Function(WatermarkProject project) onProjectUpdated;

  @override
  State<_CaptureDetailPage> createState() => _CaptureDetailPageState();
}

class _CaptureDetailPageState extends State<_CaptureDetailPage> {
  late WatermarkProject _project;
  late WatermarkProfile _profile;
  late final WatermarkProfilesController _profilesController;
  late final WatermarkContextController _contextController;
  late final WatermarkRenderer _renderer;
  late final WatermarkExporter _exporter;

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _profile = widget.initialProfile;
    final bootstrapper = widget.bootstrapper;
    _profilesController = bootstrapper.profilesController;
    _contextController = bootstrapper.contextController;
    _renderer = bootstrapper.renderer;
    _exporter = bootstrapper.exporter;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profilesController.profiles;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _project.mediaType == WatermarkMediaType.photo ? '照片详情' : '视频详情',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _exporting ? null : _exportMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildMediaPreview(_project),
                Positioned.fill(
                  child: WatermarkCanvasView(
                    elements: _profile.elements,
                    contextData: _contextController.context,
                    canvasSize: _project.canvasSize ??
                        _profile.canvasSize ??
                        const WatermarkCanvasSize(width: 1080, height: 1920),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 120,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              scrollDirection: Axis.horizontal,
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final selected = profile.id == _profile.id;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selected ? Colors.orangeAccent : Colors.white12,
                  ),
                  onPressed: () => setState(() => _profile = profile),
                  child: Text(profile.name),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _exporting ? null : _exportOriginal,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('导出原始文件'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _exporting ? null : _exportWithWatermark,
                      icon: const Icon(Icons.water_drop_outlined),
                      label: const Text('导出带水印'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(WatermarkProject project) {
    if (project.mediaType == WatermarkMediaType.photo && !kIsWeb) {
      final file = File(project.mediaPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Icon(
        project.mediaType == WatermarkMediaType.photo
            ? Icons.image_outlined
            : Icons.videocam_outlined,
        color: Colors.white30,
        size: 64,
      ),
    );
  }

  Future<void> _exportMenu() async {
    final option = await showModalBottomSheet<_ExportOption>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.water_drop_outlined),
              title: const Text('导出水印 PNG'),
              onTap: () => Navigator.pop(context, _ExportOption.watermark),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('导出原始文件'),
              onTap: () => Navigator.pop(context, _ExportOption.original),
            ),
            ListTile(
              leading: const Icon(Icons.layers),
              title: const Text('在编辑器中打开'),
              onTap: () => Navigator.pop(context, _ExportOption.edit),
            ),
          ],
        ),
      ),
    );
    switch (option) {
      case _ExportOption.watermark:
        await _exportWatermarkOnly();
        break;
      case _ExportOption.original:
        await _exportOriginal();
        break;
      case _ExportOption.edit:
        if (!mounted) {
          return;
        }
        await Navigator.of(context).pushNamed(
          ProfileEditorScreen.routeName,
          arguments: ProfileEditorArguments(
            profileId: _profile.id,
            bootstrapper: widget.bootstrapper,
            fallbackCanvasSize: _project.canvasSize,
          ),
        );
        setState(() {
          _profile = _profilesController.profiles.firstWhere(
            (item) => item.id == _project.profileId,
            orElse: () => _profilesController.profiles.first,
          );
        });
        break;
      case null:
        break;
    }
  }

  Future<void> _exportOriginal() async {
    setState(() => _exporting = true);
    final path = await _exporter.exportOriginal(_project.mediaPath);
    setState(() => _exporting = false);
    if (!mounted) {
      return;
    }
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前平台不可直接导出原始文件')),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('原始文件已导出：$path')));
    }
  }

  Future<void> _exportWatermarkOnly() async {
    setState(() => _exporting = true);
    final canvasSize = _project.canvasSize ??
        _profile.canvasSize ??
        const WatermarkCanvasSize(width: 1080, height: 1920);
    final bytes = await _renderer.renderToBytes(
      profile: _profile,
      context: _contextController.context,
      canvasSize: canvasSize.toSize(),
    );
    final path = await _exporter.exportWatermarkPng(
      bytes,
      suggestedName: '${_profile.name}.png',
    );
    setState(() => _exporting = false);
    if (!mounted) {
      return;
    }
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前平台不可直接保存 PNG')),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('水印 PNG 已导出：$path')));
    }
  }

  Future<void> _exportWithWatermark() async {
    setState(() => _exporting = true);
    final canvasSize = _project.canvasSize ??
        _profile.canvasSize ??
        const WatermarkCanvasSize(width: 1080, height: 1920);
    final overlayBytes = await _renderer.renderToBytes(
      profile: _profile,
      context: _contextController.context,
      canvasSize: canvasSize.toSize(),
    );
    String? overlayPath;
    if (!kIsWeb) {
      overlayPath = await _exporter.saveOverlayBytes(overlayBytes);
    }
    overlayPath ??= _project.overlayPath;
    String? resultPath;
    if (overlayPath != null) {
      if (_project.mediaType == WatermarkMediaType.photo) {
        resultPath = await _exporter.composePhoto(
          photoPath: _project.mediaPath,
          overlayPath: overlayPath,
        );
      } else {
        resultPath = await _exporter.composeVideo(
          videoPath: _project.mediaPath,
          overlayPath: overlayPath,
        );
      }
    }
    setState(() => _exporting = false);
    if (!mounted) {
      return;
    }
    if (resultPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前平台暂不支持合成，尝试导出水印 PNG')),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出成功：$resultPath')));
    }
  }
}

enum _ExportOption { watermark, original, edit }
