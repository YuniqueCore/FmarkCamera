import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/domain/models/watermark_project.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
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
  Map<String, Uint8List> _thumbnails = const <String, Uint8List>{};
  Map<String, WatermarkProfile> _profileIndex =
      const <String, WatermarkProfile>{};
  bool _loading = true;
  bool _generatingThumbs = false;

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
    final profiles = await _profileRepository.loadProfiles();
    final profileMap = {for (final profile in profiles) profile.id: profile};
    setState(() {
      _projects = projects.reversed.toList();
      _profileIndex = profileMap;
      _loading = false;
    });
    unawaited(_ensureThumbnails());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍摄记录'),
        actions: [
          if (_generatingThumbs)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: '刷新缩略图',
              onPressed: _ensureThumbnails,
            ),
        ],
      ),
      body: _projects.isEmpty
          ? const Center(child: Text('暂无拍摄记录'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                final thumbnail = _thumbnails[project.id];
                return GestureDetector(
                  onTap: () => _openDetail(project),
                  child: GridTile(
                    footer: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.basename(project.mediaPath),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(project.capturedAt),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: thumbnail == null
                          ? Container(
                              color: Colors.black26,
                              child: const Center(
                                  child: Icon(Icons.image_not_supported,
                                      color: Colors.white54)),
                            )
                          : Image.memory(thumbnail, fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _ensureThumbnails() async {
    if (_projects.isEmpty) {
      return;
    }
    setState(() => _generatingThumbs = true);
    final updated = {..._thumbnails};
    for (final project in _projects) {
      if (updated.containsKey(project.id)) {
        continue;
      }
      try {
        final bytes = await _composeThumbnail(project);
        if (bytes != null) {
          updated[project.id] = bytes;
        }
      } catch (_) {
        // 忽略单个缩略图失败，继续其他
      }
    }
    if (mounted) {
      setState(() {
        _thumbnails = updated;
        _generatingThumbs = false;
      });
    }
  }

  Future<Uint8List?> _composeThumbnail(WatermarkProject project) async {
    final profile = _profileIndex[project.profileId];
    if (profile == null) {
      return null;
    }
    final canvasSize = project.canvasSize?.toSize() ?? const Size(1080, 1920);
    try {
      return await _renderer.renderToBytes(
        profile: profile,
        context: _contextController.context,
        canvasSize: canvasSize,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshOverlay(WatermarkProject project) async {
    final profiles = await _profileRepository.loadProfiles();
    final profile = profiles.firstWhere((item) => item.id == project.profileId,
        orElse: () => profiles.first);
    final previewSize = project.canvasSize?.toSize() ?? const Size(1080, 1920);
    final bytes = await _renderer.renderToBytes(
      profile: profile,
      context: _contextController.context,
      canvasSize: previewSize,
    );
    final overlayPath = await _exporter.saveOverlayBytes(bytes);
    final updated = project.copyWith(overlayPath: overlayPath);
    final updatedProjects = _projects
        .map((item) => item.id == project.id ? updated : item)
        .toList();
    await _projectRepository.saveProjects(updatedProjects.reversed.toList());
    if (mounted) {
      setState(() {
        _projects = updatedProjects;
        _thumbnails = {..._thumbnails, project.id: bytes};
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('水印已更新')));
    }
  }

  void _openDetail(WatermarkProject project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ProjectDetailScreen(
          project: project,
          thumbnails: _thumbnails,
          exporter: _exporter,
          renderer: _renderer,
          contextController: _contextController,
          profiles: _profileIndex,
          onProjectUpdated: (updated) async {
            final list = _projects
                .map((item) => item.id == updated.id ? updated : item)
                .toList();
            await _projectRepository.saveProjects(list.reversed.toList());
            setState(() {
              _projects = list;
            });
            if (updated.thumbnailPath != null) {
              unawaited(_ensureThumbnails());
            }
          },
        ),
      ),
    );
  }
}

class _ProjectDetailScreen extends StatefulWidget {
  const _ProjectDetailScreen({
    required this.project,
    required this.thumbnails,
    required this.exporter,
    required this.renderer,
    required this.contextController,
    required this.profiles,
    required this.onProjectUpdated,
  });

  final WatermarkProject project;
  final Map<String, Uint8List> thumbnails;
  final WatermarkExporter exporter;
  final WatermarkRenderer renderer;
  final WatermarkContextController contextController;
  final Map<String, WatermarkProfile> profiles;
  final Future<void> Function(WatermarkProject project) onProjectUpdated;

  @override
  State<_ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<_ProjectDetailScreen> {
  late WatermarkProject _project;
  late WatermarkProfile _activeProfile;
  bool _loading = false;
  bool _exporting = false;
  Uint8List? _previewBytes;
  final PageController _pageController = PageController(viewportFraction: 0.8);

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _activeProfile =
        widget.profiles[_project.profileId] ?? widget.profiles.values.first;
    _previewBytes = widget.thumbnails[_project.id];
    _generatePreview();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.profiles.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(_project.mediaPath)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _exporting ? null : () => _showExportSheet(context),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _previewBytes == null
                  ? const CircularProgressIndicator()
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 3,
                      child: Image.memory(
                        _previewBytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onProfilePageChanged,
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final isActive = profile.id == _activeProfile.id;
                return AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 12 : 24,
                    vertical: isActive ? 8 : 16,
                  ),
                  child: Material(
                    elevation: isActive ? 4 : 1,
                    borderRadius: BorderRadius.circular(16),
                    color: isActive
                        ? Colors.orangeAccent.withValues(alpha: 0.2)
                        : Colors.white10,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _onProfileSelected(profile),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    profile.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (profile.isDefault)
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 18),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${profile.elements.length} 个元素',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                      onPressed: _exporting ? null : _exportCurrentProfile,
                      icon: const Icon(Icons.water_drop_outlined),
                      label: const Text('导出配置'),
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

  Future<void> _onProfilePageChanged(int index) async {
    final profiles = widget.profiles.values.toList();
    if (index >= 0 && index < profiles.length) {
      _onProfileSelected(profiles[index]);
    }
  }

  Future<void> _onProfileSelected(WatermarkProfile profile) async {
    if (_activeProfile.id == profile.id) {
      return;
    }
    setState(() {
      _activeProfile = profile;
    });
    await _generatePreview();
  }

  Future<void> _generatePreview() async {
    setState(() => _loading = true);
    try {
      final bytes = await widget.renderer.renderToBytes(
        profile: _activeProfile,
        context: widget.contextController.context,
        canvasSize: _project.canvasSize?.toSize() ?? const Size(1080, 1920),
      );
      setState(() {
        _previewBytes = bytes;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _exportOriginal() async {
    setState(() => _exporting = true);
    final result = await widget.exporter.exportOriginal(_project.mediaPath);
    setState(() => _exporting = false);
    if (!mounted) {
      return;
    }
    if (result == null) {
      _showUnsupportedSnack(
        _project.mediaType == WatermarkMediaType.photo
            ? '原始照片导出暂不支持，请手动下载源文件。'
            : '原始视频导出暂不支持，请手动下载源文件。',
      );
    } else {
      _showSuccessSnack('原始文件已导出：$result');
    }
  }

  Future<void> _exportCurrentProfile() async {
    await _showExportSheet(context);
  }

  Future<void> _showExportSheet(BuildContext context) async {
    if (_exporting) {
      return;
    }
    final option = await showModalBottomSheet<_ExportOption>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('导出带水印'),
                onTap: () =>
                    Navigator.of(context).pop(_ExportOption.photoWithWatermark),
              ),
              ListTile(
                leading: const Icon(Icons.water_drop_outlined),
                title: const Text('导出水印 PNG'),
                onTap: () =>
                    Navigator.of(context).pop(_ExportOption.watermarkOnly),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导出原始文件'),
                onTap: () => Navigator.of(context).pop(_ExportOption.original),
              ),
            ],
          ),
        );
      },
    );
    if (option == null) {
      return;
    }
    switch (option) {
      case _ExportOption.original:
        await _exportOriginal();
        break;
      case _ExportOption.watermarkOnly:
        await _exportWatermarkOnly();
        break;
      case _ExportOption.photoWithWatermark:
        await _exportWithWatermark();
        break;
    }
  }

  Future<void> _exportWatermarkOnly() async {
    setState(() => _exporting = true);
    final overlayBytes = await widget.renderer.renderToBytes(
      profile: _activeProfile,
      context: widget.contextController.context,
      canvasSize: _project.canvasSize?.toSize() ?? const Size(1080, 1920),
    );
    final result = await widget.exporter.exportWatermarkPng(
      overlayBytes,
      suggestedName: '${_activeProfile.name}.png',
    );
    setState(() => _exporting = false);
    if (!mounted) {
      return;
    }
    if (result == null) {
      _showUnsupportedSnack('当前平台无法直接保存水印 PNG，请手动截图或下载。');
    } else {
      _showSuccessSnack('水印 PNG 已导出：$result');
    }
  }

  Future<void> _exportWithWatermark() async {
    setState(() => _exporting = true);
    final overlayBytes = await widget.renderer.renderToBytes(
      profile: _activeProfile,
      context: widget.contextController.context,
      canvasSize: _project.canvasSize?.toSize() ?? const Size(1080, 1920),
    );
    String? overlayPath;
    if (!kIsWeb) {
      overlayPath = await widget.exporter.saveOverlayBytes(overlayBytes);
    }
    final overlay = overlayPath ?? _project.overlayPath;
    if (overlay == null) {
      setState(() => _exporting = false);
      if (mounted) {
        _showUnsupportedSnack('无法生成水印文件，请稍后再试。');
      }
      return;
    }
    String? resultPath;
    if (_project.mediaType == WatermarkMediaType.photo) {
      resultPath = await widget.exporter.composePhoto(
        photoPath: _project.mediaPath,
        overlayPath: overlay,
      );
    } else {
      resultPath = await widget.exporter.composeVideo(
        videoPath: _project.mediaPath,
        overlayPath: overlay,
      );
    }
    setState(() => _exporting = false);
    if (!mounted) {
      return;
    }
    if (resultPath == null) {
      _showUnsupportedSnack(
        _project.mediaType == WatermarkMediaType.photo
            ? '当前平台暂不支持导出带水印照片，请在移动/桌面端完成导出。'
            : '当前平台暂不支持导出带水印视频，请在移动/桌面端完成导出。',
      );
    } else {
      _showSuccessSnack('导出成功：$resultPath');
    }
  }

  void _showUnsupportedSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

enum _ExportOption {
  original,
  watermarkOnly,
  photoWithWatermark,
}
