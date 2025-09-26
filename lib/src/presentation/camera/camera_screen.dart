import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/models/watermark_project.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/watermark_context_controller.dart';
import 'package:fmark_camera/src/services/watermark_exporter.dart';
import 'package:fmark_camera/src/services/watermark_profiles_controller.dart';
import 'package:fmark_camera/src/services/watermark_projects_controller.dart';
import 'package:fmark_camera/src/services/watermark_renderer.dart';
import 'package:fmark_camera/src/presentation/gallery/gallery_screen.dart';
import 'package:fmark_camera/src/presentation/profiles/profile_editor_screen.dart';
import 'package:fmark_camera/src/presentation/profiles/profiles_screen.dart';
import 'package:fmark_camera/src/presentation/widgets/watermark_canvas.dart';

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.contextData});

  final WatermarkContext contextData;

  @override
  Widget build(BuildContext context) {
    final location = contextData.location;
    final weather = contextData.weather;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(contextData.now),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            if (location != null)
              Text(
                location.address ??
                    location.city ??
                    '${location.latitude.toStringAsFixed(2)}, ${location.longitude.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            if (weather != null)
              Text(
                '${weather.temperatureCelsius.toStringAsFixed(1)}°C ${weather.description ?? ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.bootstrapper});

  static const String routeName = '/';

  final Bootstrapper bootstrapper;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final Uuid _uuid = const Uuid();

  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = const <CameraDescription>[];
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isVideoMode = false;
  Size? _lastSyncedCanvasSize;

  late final WatermarkProfilesController _profilesController;
  late final WatermarkProjectsController _projectsController;
  late final WatermarkContextController _contextController;
  late final WatermarkRenderer _renderer;
  late final WatermarkExporter _exporter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final bootstrapper = widget.bootstrapper;
    _profilesController = bootstrapper.profilesController;
    _projectsController = bootstrapper.projectsController;
    _contextController = bootstrapper.contextController;
    _renderer = bootstrapper.renderer;
    _exporter = bootstrapper.exporter;
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Web端需要特殊处理权限
    if (kIsWeb) {
      try {
        // Web端权限请求需要在用户手势中触发
        final permission = await Permission.camera.request();
        if (!permission.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要相机权限才能使用此功能'),
              action: SnackBarAction(
                label: '设置',
                onPressed: openAppSettings,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        // Web端权限API可能抛出异常，忽略并继续
        debugPrint('Web camera permission check: $e');
      }
    } else {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        return;
      }
    }

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到可用的相机')),
        );
        return;
      }
      final controller = CameraController(
        _availableCameras.first,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      await _profilesController.ensureCanvasSize(
        _canvasSizeFromPreview(controller.value.previewSize),
        force: true,
      );
      setState(() {
        _cameraController = controller;
        _isInitialized = true;
        _lastSyncedCanvasSize = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('相机初始化失败: $e'),
          action: SnackBarAction(
            label: '重试',
            onPressed: _initializeCamera,
          ),
        ),
      );
      return;
    }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    if (!_isInitialized || controller == null) {
      return _buildCameraUnavailable();
    }
    return AnimatedBuilder(
      animation: Listenable.merge([
        _profilesController,
        _contextController,
      ]),
      builder: (context, _) {
        final activeProfile = _profilesController.activeProfile;
        final contextData = _contextController.context;
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Fmark Camera'),
            actions: [
              IconButton(
                tooltip: '管理 Profile',
                icon: const Icon(Icons.layers_outlined),
                onPressed: () => Navigator.of(context).pushNamed(
                  ProfilesScreen.routeName,
                ),
              ),
              IconButton(
                tooltip: '编辑当前 Profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: activeProfile == null
                    ? null
                    : () {
                        final previewSize = controller.value.previewSize;
                        Navigator.of(context).pushNamed(
                          ProfileEditorScreen.routeName,
                          arguments: ProfileEditorArguments(
                            profileId: activeProfile.id,
                            bootstrapper: widget.bootstrapper,
                            fallbackCanvasSize: previewSize == null
                                ? activeProfile.canvasSize
                                : WatermarkCanvasSize(
                                    width: previewSize.width,
                                    height: previewSize.height,
                                  ),
                          ),
                        );
                      },
              ),
              IconButton(
                tooltip: '图库',
                icon: const Icon(Icons.collections_outlined),
                onPressed: () =>
                    Navigator.of(context).pushNamed(GalleryScreen.routeName),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _syncCanvasSizeIfNeeded(context, controller);
                    return Stack(
                      children: [
                        _buildPreviewLayer(
                          context: context,
                          constraints: constraints,
                          controller: controller,
                          activeProfile: activeProfile,
                          contextData: contextData,
                        ),
                        Positioned(
                          left: 16,
                          top: 16,
                          child: _ContextBadge(contextData: contextData),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _buildBottomBar(activeProfile),
            ],
          ),
        );
      },
    );
  }

  // Private helper methods - all methods moved here
  WatermarkCanvasSize _fallbackCanvasSize() =>
      const WatermarkCanvasSize(width: 1080, height: 1920);

  WatermarkCanvasSize _canvasSizeFromPreview(Size? previewSize) {
    final size = previewSize ?? _fallbackCanvasSize().toSize();
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final devicePixelRatio = views.isNotEmpty
        ? views.first.devicePixelRatio
        : (WidgetsBinding
                .instance.platformDispatcher.implicitView?.devicePixelRatio ??
            1);
    return WatermarkCanvasSize(
      width: size.width,
      height: size.height,
      pixelRatio: devicePixelRatio,
    );
  }

  Widget _buildPreviewLayer({
    required BuildContext context,
    required BoxConstraints constraints,
    required CameraController controller,
    required WatermarkProfile? activeProfile,
    required WatermarkContext contextData,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final orientation = mediaQuery.orientation;
    final previewSize = _effectivePreviewSize(
      controller.value.previewSize,
      orientation,
    );
    final aspectRatio = previewSize.width / previewSize.height;
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : previewSize.width;
    final maxHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : previewSize.height;
    double width = maxWidth;
    double height = width / aspectRatio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }
    final pixelRatio = mediaQuery.devicePixelRatio;
    final canvasSize = _resolveCanvasSize(
      activeProfile,
      previewSize,
      pixelRatio,
    );
    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              if (activeProfile != null)
                Positioned.fill(
                  child: WatermarkCanvasView(
                    elements: activeProfile.elements,
                    contextData: contextData,
                    canvasSize: canvasSize,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _syncCanvasSizeIfNeeded(
    BuildContext context,
    CameraController controller,
  ) {
    final preview = controller.value.previewSize;
    if (preview == null || !mounted) {
      return;
    }
    final orientation = MediaQuery.of(context).orientation;
    final effective = _effectivePreviewSize(preview, orientation);
    if (_lastSyncedCanvasSize != null) {
      final last = _lastSyncedCanvasSize!;
      if ((last.width - effective.width).abs() < 0.5 &&
          (last.height - effective.height).abs() < 0.5) {
        return;
      }
    }
    _lastSyncedCanvasSize = effective;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _profilesController.ensureCanvasSize(
        WatermarkCanvasSize(
          width: effective.width,
          height: effective.height,
          pixelRatio: MediaQuery.of(context).devicePixelRatio,
        ),
        force: true,
        tolerance: 0.02,
      );
    });
  }

  Size _effectivePreviewSize(Size? previewSize, Orientation orientation) {
    final fallback = _fallbackCanvasSize().toSize();
    if (previewSize == null ||
        previewSize.width <= 0 ||
        previewSize.height <= 0) {
      return fallback;
    }
    final isLandscapePreview = previewSize.width >= previewSize.height;
    if (orientation == Orientation.portrait && isLandscapePreview) {
      return Size(previewSize.height, previewSize.width);
    }
    if (orientation == Orientation.landscape && !isLandscapePreview) {
      return Size(previewSize.height, previewSize.width);
    }
    return previewSize;
  }

  WatermarkCanvasSize _resolveCanvasSize(
    WatermarkProfile? profile,
    Size fallback,
    double pixelRatio,
  ) {
    final candidate = profile?.canvasSize;
    if (candidate == null || candidate.width <= 0 || candidate.height <= 0) {
      return WatermarkCanvasSize(
        width: fallback.width,
        height: fallback.height,
        pixelRatio: pixelRatio,
      );
    }
    final candidateAspect = candidate.width / candidate.height;
    final fallbackAspect = fallback.width / fallback.height;
    if ((candidateAspect - fallbackAspect).abs() > 0.02) {
      return WatermarkCanvasSize(
        width: fallback.width,
        height: fallback.height,
        pixelRatio: pixelRatio,
      );
    }
    return candidate.copyWith(pixelRatio: pixelRatio);
  }

  Widget _buildBottomBar(WatermarkProfile? activeProfile) {
    final controller = _cameraController;
    final profiles = _profilesController.profiles;
    final activeId = activeProfile?.id;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profiles.length > 1)
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final selected = profile.id == activeId;
                    return ChoiceChip(
                      label: Text(profile.name),
                      selected: selected,
                      onSelected: (_) =>
                          _profilesController.setActive(profile.id),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: profiles.length,
                ),
              ),
            if (profiles.length > 1) const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.cameraswitch_outlined,
                      color: Colors.white),
                  onPressed: _switchCamera,
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: controller == null
                      ? null
                      : (_isVideoMode ? _toggleVideoRecording : _capturePhoto),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.white,
                        shape:
                            _isVideoMode ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius:
                            _isVideoMode ? BorderRadius.circular(12) : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: Icon(
                    _isVideoMode ? Icons.videocam : Icons.camera,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _isVideoMode = !_isVideoMode),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraUnavailable() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                '正在初始化相机或无法访问相机。\n在 Web 上可能不支持或被浏览器拦截。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) {
      return;
    }
    final controller = _cameraController;
    if (controller == null) {
      return;
    }
    final currentIndex = _availableCameras.indexOf(controller.description);
    final nextIndex = (currentIndex + 1) % _availableCameras.length;
    final nextCamera = _availableCameras[nextIndex];
    final newController =
        CameraController(nextCamera, ResolutionPreset.high, enableAudio: true);
    await newController.initialize();
    await controller.dispose();
    await _profilesController.ensureCanvasSize(
      _canvasSizeFromPreview(newController.value.previewSize),
      force: true,
    );
    setState(() {
      _cameraController = newController;
      _lastSyncedCanvasSize = null;
    });
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    final profile = _profilesController.activeProfile;
    if (controller == null || profile == null) {
      return;
    }
    final file = await controller.takePicture();
    String? mediaDataBase64;
    if (kIsWeb) {
      try {
        final bytes = await file.readAsBytes();
        mediaDataBase64 = base64Encode(bytes);
      } catch (_) {
        mediaDataBase64 = null;
      }
    }
    await _storeCapture(
      path: file.path,
      mediaType: WatermarkMediaType.photo,
      previewSize: controller.value.previewSize,
      aspectRatio: controller.value.aspectRatio,
      profile: profile,
      mediaDataBase64: mediaDataBase64,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('照片已保存，可在图库中导出水印版本')),
    );
  }

  Future<void> _toggleVideoRecording() async {
    final controller = _cameraController;
    final profile = _profilesController.activeProfile;
    if (controller == null || profile == null) {
      return;
    }
    if (_isRecording) {
      final file = await controller.stopVideoRecording();
      setState(() => _isRecording = false);
      await _storeCapture(
        path: file.path,
        mediaType: WatermarkMediaType.video,
        previewSize: controller.value.previewSize,
        aspectRatio: controller.value.aspectRatio,
        profile: profile,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('视频已保存，可在图库中导出水印版本')),
      );
    } else {
      if (!controller.value.isInitialized) {
        return;
      }
      try {
        await controller.prepareForVideoRecording();
      } catch (_) {
        // 某些平台无需显式 prepare
      }
      await controller.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _storeCapture({
    required String path,
    required WatermarkMediaType mediaType,
    required Size? previewSize,
    required double aspectRatio,
    required WatermarkProfile profile,
    String? mediaDataBase64,
    String? thumbnailData,
  }) async {
    final contextData = _contextController.context;
    final canvasSize = profile.canvasSize ??
        (previewSize == null
            ? _fallbackCanvasSize()
            : _canvasSizeFromPreview(previewSize));
    String? overlayPath;
    String? overlayData;
    String? resolvedThumbnail = thumbnailData;
    try {
      final bytes = await _renderer.renderToBytes(
        profile: profile,
        context: contextData,
        canvasSize: canvasSize.toSize(),
      );
      if (kIsWeb) {
        overlayData = base64Encode(bytes);
        resolvedThumbnail ??= overlayData;
      } else {
        overlayPath = await _exporter.saveOverlayBytes(bytes);
      }
    } catch (_) {
      overlayPath = null;
      overlayData = null;
    }

    final project = WatermarkProject(
      id: _uuid.v4(),
      mediaPath: path,
      mediaType: mediaType,
      capturedAt: DateTime.now(),
      profileId: profile.id,
      canvasSize: canvasSize,
      previewRatio: aspectRatio,
      overlayPath: overlayPath,
      overlayData: overlayData,
      thumbnailData: resolvedThumbnail,
      mediaDataBase64: mediaDataBase64,
    );
    await _projectsController.addProject(project);
  }

}

