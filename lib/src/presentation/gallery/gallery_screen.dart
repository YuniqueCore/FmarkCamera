import 'dart:convert';
import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

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

Widget? _videoThumbnailForProject(
  WatermarkProject project, {
  BoxFit fit = BoxFit.cover,
}) {
  final base64Thumb = project.thumbnailData;
  if (base64Thumb != null && base64Thumb.isNotEmpty) {
    try {
      final bytes = base64Decode(base64Thumb);
      if (bytes.isNotEmpty) {
        return Image.memory(bytes, fit: fit);
      }
    } catch (_) {}
  }
  if (!kIsWeb) {
    final thumbPath = project.thumbnailPath;
    if (thumbPath != null && thumbPath.isNotEmpty) {
      final file = File(thumbPath);
      if (file.existsSync()) {
        return Image.file(file, fit: fit);
      }
    }
  }
  return null;
}

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
                                  width: 1080,
                                  height: 1920,
                                ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.white,
                              onPressed: () => _confirmDelete(project),
                              tooltip: '删除',
                            ),
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
                                  DateFormat(
                                    'yyyy-MM-dd HH:mm',
                                  ).format(project.capturedAt),
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

  Future<void> _confirmDelete(WatermarkProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除拍摄记录'),
        content: const Text('删除后将移除媒资及关联水印配置，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _deleteProject(project);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已删除拍摄记录')));
  }

  Future<void> _deleteProject(WatermarkProject project) async {
    if (!kIsWeb) {
      try {
        if (project.mediaPath.isNotEmpty) {
          final file = File(project.mediaPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (_) {}
      final overlayPath = project.overlayPath;
      if (overlayPath != null && overlayPath.isNotEmpty) {
        try {
          final overlayFile = File(overlayPath);
          if (await overlayFile.exists()) {
            await overlayFile.delete();
          }
        } catch (_) {}
      }
    }
    await _projectsController.removeProject(project.id);
  }

  Widget _buildMediaPreview(WatermarkProject project) {
    if (project.mediaType == WatermarkMediaType.photo) {
      if (kIsWeb) {
        final base64 = project.mediaDataBase64 ?? project.thumbnailData;
        if (base64 != null && base64.isNotEmpty) {
          try {
            final bytes = base64Decode(base64);
            return Image.memory(bytes, fit: BoxFit.cover);
          } catch (_) {}
        }
      } else {
        final file = File(project.mediaPath);
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover);
        }
      }
    } else if (project.mediaType == WatermarkMediaType.video) {
      final videoThumb = _videoThumbnailForProject(project);
      if (videoThumb != null) {
        return videoThumb;
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

  Future<void> _openDetail(
      WatermarkProject project, WatermarkProfile profile) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CaptureDetailPage(
          project: project,
          initialProfile: profile,
          bootstrapper: widget.bootstrapper,
          onProjectUpdated: (updated) async {
            await _projectsController.updateProject(updated);
          },
          onProjectDeleted: (deleted) async {
            await _deleteProject(deleted);
          },
        ),
      ),
    );
    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除拍摄记录')));
    }
  }
}

class _CaptureDetailPage extends StatefulWidget {
  const _CaptureDetailPage({
    required this.project,
    required this.initialProfile,
    required this.bootstrapper,
    required this.onProjectUpdated,
    this.onProjectDeleted,
  });

  final WatermarkProject project;
  final WatermarkProfile initialProfile;
  final Bootstrapper bootstrapper;
  final Future<void> Function(WatermarkProject project) onProjectUpdated;
  final Future<void> Function(WatermarkProject project)? onProjectDeleted;

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
            icon: const Icon(Icons.delete_outline),
            onPressed: _exporting ? null : _confirmDeleteCurrent,
          ),
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
    if (project.mediaType == WatermarkMediaType.photo) {
      if (kIsWeb) {
        final base64 = project.mediaDataBase64 ?? project.thumbnailData;
        if (base64 != null && base64.isNotEmpty) {
          try {
            final bytes = base64Decode(base64);
            return Image.memory(bytes, fit: BoxFit.contain);
          } catch (_) {}
        }
      } else {
        final file = File(project.mediaPath);
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.contain);
        }
      }
    } else if (project.mediaType == WatermarkMediaType.video) {
      final videoThumb = _videoThumbnailForProject(
        project,
        fit: BoxFit.contain,
      );
      if (videoThumb != null) {
        return videoThumb;
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

  WatermarkMediaInput? _mediaInputForProject(WatermarkProject project) {
    if (!kIsWeb && project.mediaPath.isNotEmpty) {
      return WatermarkMediaInput.fromPath(project.mediaPath);
    }
    final base64Data = project.mediaDataBase64;
    if (base64Data != null && base64Data.isNotEmpty) {
      try {
        return WatermarkMediaInput.fromBytes(base64Decode(base64Data));
      } catch (_) {}
    }
    if (project.mediaPath.isNotEmpty) {
      return WatermarkMediaInput.fromPath(project.mediaPath);
    }
    return null;
  }

  WatermarkMediaInput? _overlayInput({
    Uint8List? overlayBytes,
    required WatermarkProject project,
  }) {
    if (overlayBytes != null && overlayBytes.isNotEmpty) {
      return WatermarkMediaInput.fromBytes(overlayBytes);
    }
    final overlayData = project.overlayData;
    if (overlayData != null && overlayData.isNotEmpty) {
      try {
        return WatermarkMediaInput.fromBytes(base64Decode(overlayData));
      } catch (_) {}
    }
    final overlayPath = project.overlayPath;
    if (overlayPath != null && overlayPath.isNotEmpty) {
      return WatermarkMediaInput.fromPath(overlayPath);
    }
    return null;
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

  Future<void> _confirmDeleteCurrent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除拍摄记录'),
        content: const Text('删除后将移除媒资及关联水印配置，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (widget.onProjectDeleted != null) {
      await widget.onProjectDeleted!(_project);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _exportOriginal() async {
    final mediaInput = _mediaInputForProject(_project);
    if (mediaInput == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到原始媒资文件')),
      );
      return;
    }
    setState(() => _exporting = true);
    final result = await _exporter.exportOriginal(
      mediaInput,
      mediaType: _project.mediaType,
    );
    setState(() => _exporting = false);
    if (!mounted) {
      return;
    }
    final message = result.userMessage ??
        (result.success
            ? '原始文件已准备：${result.outputPath ?? '请手动查看'}'
            : '当前平台不可直接导出原始文件');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportWatermarkOnly() async {
    setState(() => _exporting = true);
    final baseCanvasSize = _project.canvasSize ??
        _profile.canvasSize ??
        const WatermarkCanvasSize(width: 1080, height: 1920);
    final targetSize = await _resolveMediaDimensions();
    var renderCanvasSize = baseCanvasSize;
    var scaleFactor = 1.0;
    if (targetSize != null && targetSize.width > 0 && targetSize.height > 0) {
      renderCanvasSize = WatermarkCanvasSize(
        width: targetSize.width,
        height: targetSize.height,
        pixelRatio: baseCanvasSize.pixelRatio,
      );
      if (baseCanvasSize.width > 0) {
        scaleFactor = targetSize.width / baseCanvasSize.width;
      }
    }
    final bytes = await _renderer.renderToBytes(
      profile: _profile,
      context: _contextController.context,
      canvasSize: renderCanvasSize.toSize(),
      scaleFactor: scaleFactor,
    );
    final result = await _exporter.exportWatermarkPng(
      WatermarkMediaInput.fromBytes(bytes),
      suggestedName: '${_profile.name}.png',
      options: const WatermarkExportOptions(
        destination: WatermarkExportDestination.filePicker,
      ),
    );
    setState(() => _exporting = false);
    if (!mounted) {
      return;
    }
    final message = result.userMessage ??
        (result.success
            ? '水印 PNG 已导出：${result.outputPath ?? '已保存'}'
            : '当前平台不可直接保存 PNG');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportWithWatermark() async {
    setState(() => _exporting = true);
    final baseCanvasSize = _project.canvasSize ??
        _profile.canvasSize ??
        const WatermarkCanvasSize(width: 1080, height: 1920);
    final targetSize = await _resolveMediaDimensions();
    var renderCanvasSize = baseCanvasSize;
    var scaleFactor = 1.0;
    if (targetSize != null && targetSize.width > 0 && targetSize.height > 0) {
      renderCanvasSize = WatermarkCanvasSize(
        width: targetSize.width,
        height: targetSize.height,
        pixelRatio: baseCanvasSize.pixelRatio,
      );
      if (baseCanvasSize.width > 0) {
        scaleFactor = targetSize.width / baseCanvasSize.width;
      }
    }
    final overlayBytes = await _renderer.renderToBytes(
      profile: _profile,
      context: _contextController.context,
      canvasSize: renderCanvasSize.toSize(),
      scaleFactor: scaleFactor,
    );
    WatermarkMediaInput? overlayInput;
    if (kIsWeb) {
      overlayInput = WatermarkMediaInput.fromBytes(overlayBytes);
    } else {
      final overlayPath = await _exporter.saveOverlayBytes(overlayBytes);
      if (overlayPath != null && overlayPath.isNotEmpty) {
        overlayInput = WatermarkMediaInput.fromPath(overlayPath);
      }
    }
    overlayInput ??= _overlayInput(
        overlayBytes: kIsWeb ? overlayBytes : null, project: _project);
    final mediaInput = _mediaInputForProject(_project);
    if (overlayInput == null || mediaInput == null) {
      setState(() => _exporting = false);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未生成水印图层，无法导出')),
      );
      return;
    }
    final WatermarkExportResult result;
    if (_project.mediaType == WatermarkMediaType.photo) {
      result = await _exporter.composePhoto(
        photo: mediaInput,
        overlay: overlayInput,
        options: WatermarkExportOptions(
          destination: WatermarkExportDestination.gallery,
          suggestedFileName: '${_profile.name}_${_project.id}.jpg',
        ),
      );
    } else {
      result = await _exporter.composeVideo(
        video: mediaInput,
        overlay: overlayInput,
        options: WatermarkExportOptions(
          destination: WatermarkExportDestination.gallery,
          suggestedFileName: '${_profile.name}_${_project.id}.mp4',
        ),
      );
    }
    setState(() => _exporting = false);
    if (!mounted) {
      return;
    }
    final message = result.userMessage ??
        (result.success ? '导出成功：${result.outputPath ?? '已保存'}' : '导出失败，请稍后重试');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Size?> _resolveMediaDimensions() async {
    if (_project.mediaType == WatermarkMediaType.photo) {
      return _resolvePhotoDimensions();
    }
    return _resolveVideoDimensions();
  }

  Future<Size?> _resolvePhotoDimensions() async {
    try {
      if (!kIsWeb && _project.mediaPath.isNotEmpty) {
        final file = File(_project.mediaPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return _decodeImageSize(bytes);
        }
      }
      final base64Data = _project.mediaDataBase64 ?? _project.thumbnailData;
      if (base64Data != null && base64Data.isNotEmpty) {
        final bytes = base64Decode(base64Data);
        return _decodeImageSize(bytes);
      }
    } catch (error) {
      debugPrint('Resolve photo dimension failed: $error');
    }
    return null;
  }

  Future<Size?> _resolveVideoDimensions() async {
    if (kIsWeb || _project.mediaPath.isEmpty) {
      return null;
    }
    final file = File(_project.mediaPath);
    if (!file.existsSync()) {
      return null;
    }
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(file);
      await controller.initialize();
      final size = controller.value.size;
      if (size.width <= 0 || size.height <= 0) {
        return null;
      }
      return size;
    } catch (error) {
      debugPrint('Resolve video dimension failed: $error');
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  Future<Size?> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      codec.dispose();
      return Size(image.width.toDouble(), image.height.toDouble());
    } catch (error) {
      debugPrint('Decode image size failed: $error');
      return null;
    }
  }
}

enum _ExportOption { watermark, original, edit }
