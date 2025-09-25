import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_element_payload.dart';
import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/models/watermark_project.dart';
import 'package:fmark_camera/src/domain/models/watermark_transform.dart';
import 'package:fmark_camera/src/domain/repositories/project_repository.dart';
import 'package:fmark_camera/src/domain/repositories/watermark_profile_repository.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/watermark_context_controller.dart';
import 'package:fmark_camera/src/services/watermark_exporter.dart';
import 'package:fmark_camera/src/services/watermark_renderer.dart';
import 'package:fmark_camera/src/presentation/gallery/gallery_screen.dart';
import 'package:fmark_camera/src/presentation/templates/template_manager_screen.dart';
import 'package:fmark_camera/src/presentation/widgets/context_badge.dart';
import 'package:fmark_camera/src/presentation/camera/widgets/watermark_canvas.dart';

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
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isVideoMode = false;
  bool _isEditing = true;
  String? _selectedElementId;
  List<WatermarkProfile> _profiles = const <WatermarkProfile>[];
  WatermarkProfile? _activeProfile;
  List<WatermarkProject> _projects = const <WatermarkProject>[];

  WatermarkProfileRepository get _profileRepository =>
      widget.bootstrapper.profileRepository;
  ProjectRepository get _projectRepository =>
      widget.bootstrapper.projectRepository;
  WatermarkRenderer get _renderer => widget.bootstrapper.renderer;
  WatermarkContextController get _contextController =>
      widget.bootstrapper.contextController;
  WatermarkExporter get _exporter => widget.bootstrapper.exporter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepare();
  }

  Future<void> _prepare() async {
    await _loadData();
    await _initializeCamera();
  }

  Future<void> _loadData() async {
    final profiles = await _profileRepository.loadProfiles();
    final projects = await _projectRepository.loadProjects();
    setState(() {
      _profiles = profiles;
      _projects = projects;
      _activeProfile = profiles.isNotEmpty
          ? profiles.firstWhere(
              (profile) => profile.isDefault,
              orElse: () => profiles.first,
            )
          : null;
    });
  }

  Future<void> _initializeCamera() async {
    if (!kIsWeb) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        return;
      }
    }
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      return;
    }
    final controller = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: true,
    );
    await controller.initialize();
    setState(() {
      _controller = controller;
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    // On web, controller dispose during tab backgrounding can race with rebuild.
    // Keep it simple: only reinitialize on resumed; avoid disposing here.
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Fmark Camera'),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            onPressed: _activeProfile == null
                ? null
                : () async {
                    final selected = await Navigator.of(context).pushNamed(
                      TemplateManagerScreen.routeName,
                      arguments: TemplateManagerArguments(
                          activeProfileId: _activeProfile!.id),
                    ) as WatermarkProfile?;
                    if (selected != null) {
                      setState(() => _activeProfile = selected);
                      await _persistProfiles();
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.collections_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(GalleryScreen.routeName),
          ),
        ],
      ),
      body: !_isInitialized || controller == null
          ? _buildCameraUnavailable()
          : AnimatedBuilder(
              animation: _contextController,
              builder: (context, _) {
                return Column(
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
                          Positioned.fill(
                            child: _buildWatermarkLayer(
                                _contextController.context),
                          ),
                          Positioned(
                            left: 16,
                            top: 16,
                            child: ContextBadge(
                                contextData: _contextController.context),
                          ),
                        ],
                      ),
                    ),
                    _buildControls(),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCameraUnavailable() {
    return Center(
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
    );
  }

  Widget _buildWatermarkLayer(WatermarkContext contextData) {
    final profile = _activeProfile;
    if (profile == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      ignoring: !_isEditing,
      child: WatermarkCanvas(
        elements: profile.elements,
        contextData: contextData,
        selectedElementId: _selectedElementId,
        isEditing: _isEditing,
        onElementSelected: (elementId) {
          setState(() => _selectedElementId = elementId);
        },
        onElementChanged: (element) {
          final updated = profile.elements
              .map((item) => item.id == element.id ? element : item)
              .toList();
          _updateProfile(
              profile.copyWith(elements: updated, updatedAt: DateTime.now()));
        },
        onElementDeleted: (elementId) {
          final updated = profile.elements
              .where((element) => element.id != elementId)
              .toList();
          _updateProfile(
              profile.copyWith(elements: updated, updatedAt: DateTime.now()));
          setState(() => _selectedElementId = null);
        },
      ),
    );
  }

  Widget _buildControls() {
    final controller = _controller;
    final cameraAvailable =
        controller != null && controller.value.isInitialized;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _buildAddButton(
                          label: '时间',
                          icon: Icons.access_time,
                          onPressed: () =>
                              _addElement(WatermarkElementType.time)),
                      _buildAddButton(
                          label: '地点',
                          icon: Icons.place_outlined,
                          onPressed: () =>
                              _addElement(WatermarkElementType.location)),
                      _buildAddButton(
                          label: '天气',
                          icon: Icons.wb_sunny_outlined,
                          onPressed: () =>
                              _addElement(WatermarkElementType.weather)),
                      _buildAddButton(
                          label: '文本',
                          icon: Icons.text_fields,
                          onPressed: () =>
                              _addElement(WatermarkElementType.text)),
                      _buildAddButton(
                          label: '图片',
                          icon: Icons.image_outlined,
                          onPressed: _addImageElement),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                  icon: Icon(_isEditing
                      ? Icons.visibility_off_outlined
                      : Icons.edit_outlined),
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                  onTap: cameraAvailable
                      ? (_isVideoMode ? _toggleVideoRecording : _capturePhoto)
                      : null,
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
                  icon: Icon(_isVideoMode ? Icons.videocam : Icons.camera,
                      color: Colors.white),
                  onPressed: () => setState(() => _isVideoMode = !_isVideoMode),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(
      {required String label,
      required IconData icon,
      required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      return;
    }
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final currentIndex = _cameras.indexOf(controller.description);
    final nextIndex = (currentIndex + 1) % _cameras.length;
    final nextCamera = _cameras[nextIndex];
    final newController =
        CameraController(nextCamera, ResolutionPreset.high, enableAudio: true);
    await newController.initialize();
    await controller.dispose();
    setState(() {
      _controller = newController;
    });
  }

  Future<void> _addElement(WatermarkElementType type) async {
    final profile = _activeProfile;
    if (profile == null) {
      return;
    }
    if (type == WatermarkElementType.image) {
      await _addImageElement();
      return;
    }
    WatermarkElement element;
    switch (type) {
      case WatermarkElementType.text:
        element = WatermarkElement(
          id: _uuid.v4(),
          type: type,
          transform: const WatermarkTransform(
              position: Offset(0.5, 0.5), scale: 1, rotation: 0),
          payload: const WatermarkElementPayload(text: '自定义文本'),
        );
        break;
      case WatermarkElementType.time:
        element = WatermarkElement(
          id: _uuid.v4(),
          type: type,
          transform: const WatermarkTransform(
              position: Offset(0.5, 0.2), scale: 1, rotation: 0),
        );
        break;
      case WatermarkElementType.location:
        element = WatermarkElement(
          id: _uuid.v4(),
          type: type,
          transform: const WatermarkTransform(
              position: Offset(0.5, 0.3), scale: 1, rotation: 0),
        );
        break;
      case WatermarkElementType.weather:
        element = WatermarkElement(
          id: _uuid.v4(),
          type: type,
          transform: const WatermarkTransform(
              position: Offset(0.5, 0.4), scale: 1, rotation: 0),
        );
        break;
      case WatermarkElementType.image:
        return;
    }
    final updated = [...profile.elements, element];
    _updateProfile(
        profile.copyWith(elements: updated, updatedAt: DateTime.now()));
    setState(() => _selectedElementId = element.id);
  }

  Future<void> _addImageElement() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) {
      return;
    }
    final profile = _activeProfile;
    if (profile == null) {
      return;
    }
    final element = WatermarkElement(
      id: _uuid.v4(),
      type: WatermarkElementType.image,
      transform: const WatermarkTransform(
          position: Offset(0.5, 0.5), scale: 1, rotation: 0),
      payload: WatermarkElementPayload(imagePath: file.path),
    );
    final updated = [...profile.elements, element];
    _updateProfile(
        profile.copyWith(elements: updated, updatedAt: DateTime.now()));
    setState(() => _selectedElementId = element.id);
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    final profile = _activeProfile;
    if (controller == null ||
        profile == null ||
        controller.value.isTakingPicture) {
      return;
    }
    final file = await controller.takePicture();
    await _saveProject(
      path: file.path,
      mediaType: WatermarkMediaType.photo,
      previewSize: controller.value.previewSize,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片已保存，可在图库中导出水印版本')),
      );
    }
  }

  Future<void> _toggleVideoRecording() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (_isRecording) {
      final file = await controller.stopVideoRecording();
      setState(() => _isRecording = false);
      await _saveProject(
        path: file.path,
        mediaType: WatermarkMediaType.video,
        previewSize: controller.value.previewSize,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('视频已保存，可在图库中导出水印版本')),
        );
      }
    } else {
      await controller.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _saveProject({
    required String path,
    required WatermarkMediaType mediaType,
    required Size? previewSize,
  }) async {
    final profile = _activeProfile;
    if (profile == null) {
      return;
    }
    final contextData = _contextController.context;
    final size = previewSize ?? const Size(1080, 1920);
    String? overlayPath;
    try {
      final bytes = await _renderer.renderToBytes(
        profile: profile,
        context: contextData,
        canvasSize: size,
      );
      if (!kIsWeb) {
        final overlayFile = await _exporter.saveOverlayBytes(bytes);
        overlayPath = overlayFile.path;
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
      overlayPath: overlayPath,
    );
    final updatedProjects = [..._projects, project];
    await _projectRepository.saveProjects(updatedProjects);
    setState(() => _projects = updatedProjects);
  }

  Future<void> _updateProfile(WatermarkProfile profile) async {
    final profiles = _profiles
        .map((item) => item.id == profile.id ? profile : item)
        .toList();
    await _profileRepository.saveProfiles(profiles);
    setState(() {
      _profiles = profiles;
      _activeProfile = profile;
    });
  }

  Future<void> _persistProfiles() async {
    await _profileRepository.saveProfiles(_profiles);
  }
}
