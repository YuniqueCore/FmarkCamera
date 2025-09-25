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
    if (!kIsWeb) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        return;
      }
    }
    _availableCameras = await availableCameras();
    if (_availableCameras.isEmpty) {
      return;
    }
    final controller = CameraController(
      _availableCameras.first,
      ResolutionPreset.high,
      enableAudio: true,
    );
    await controller.initialize();
    await _profilesController.ensureCanvasSize(
      WatermarkCanvasSize(
        width: controller.value.previewSize?.width ?? 1080,
        height: controller.value.previewSize?.height ?? 1920,
      ),
    );
    setState(() {
      _cameraController = controller;
      _isInitialized = true;
    });
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
                child: Stack(
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      ),
                    ),
                    if (activeProfile != null)
                      Positioned.fill(
                        child: WatermarkCanvasView(
                          elements: activeProfile.elements,
                          contextData: contextData,
                          canvasSize:
                              activeProfile.canvasSize ?? _fallbackCanvasSize(),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: _ContextBadge(contextData: contextData),
                    ),
                  ],
                ),
              ),
              _buildBottomBar(activeProfile),
            ],
          ),
        );
      },
    );
  }

  WatermarkCanvasSize _fallbackCanvasSize() =>
      const WatermarkCanvasSize(width: 1080, height: 1920);

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
      WatermarkCanvasSize(
        width: newController.value.previewSize?.width ?? 1080,
        height: newController.value.previewSize?.height ?? 1920,
      ),
    );
    setState(() {
      _cameraController = newController;
    });
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    final profile = _profilesController.activeProfile;
    if (controller == null || profile == null) {
      return;
    }
    final file = await controller.takePicture();
    await _storeCapture(
      path: file.path,
      mediaType: WatermarkMediaType.photo,
      previewSize: controller.value.previewSize,
      aspectRatio: controller.value.aspectRatio,
      profile: profile,
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
  }) async {
    final contextData = _contextController.context;
    final canvasSize = profile.canvasSize ?? _fallbackCanvasSize();
    String? overlayPath;
    try {
      final bytes = await _renderer.renderToBytes(
        profile: profile,
        context: contextData,
        canvasSize: canvasSize.toSize(),
      );
      if (!kIsWeb) {
        overlayPath = await _exporter.saveOverlayBytes(bytes);
      }
    } catch (_) {
      overlayPath = null;
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
    );
    await _projectsController.addProject(project);
  }
}

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
