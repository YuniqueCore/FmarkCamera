import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

import 'package:fmark_camera/src/domain/models/camera_resolution_info.dart';
import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/models/watermark_project.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/camera_settings_controller.dart';
import 'package:fmark_camera/src/services/watermark_context_controller.dart';
import 'package:fmark_camera/src/services/watermark_exporter.dart';
import 'package:fmark_camera/src/services/watermark_profiles_controller.dart';
import 'package:fmark_camera/src/services/watermark_projects_controller.dart';
import 'package:fmark_camera/src/services/watermark_renderer.dart';
import 'package:fmark_camera/src/presentation/gallery/gallery_screen.dart';
import 'package:fmark_camera/src/presentation/profiles/profile_editor_screen.dart';
import 'package:fmark_camera/src/presentation/profiles/profiles_screen.dart';
import 'package:fmark_camera/src/presentation/settings/settings_screen.dart';
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
  int _cameraIndex = 0;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isVideoMode = false;
  Size? _lastSyncedCanvasSize;
  Size? _currentPreviewSize;
  FlashMode _flashMode = FlashMode.auto;
  Offset? _focusIndicatorNormalized;
  Timer? _focusIndicatorTimer;
  ResolutionPreset? _lastAppliedPhotoPreset;
  ResolutionPreset? _lastAppliedVideoPreset;

  late final CameraSettingsController _settingsController;
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
    _settingsController = bootstrapper.cameraSettingsController;
    _settingsController.addListener(_handleSettingsChanged);
    _profilesController = bootstrapper.profilesController;
    _projectsController = bootstrapper.projectsController;
    _contextController = bootstrapper.contextController;
    _renderer = bootstrapper.renderer;
    _exporter = bootstrapper.exporter;
    _initialize();
  }

  CameraCaptureMode get _currentMode =>
      _isVideoMode ? CameraCaptureMode.video : CameraCaptureMode.photo;

  ResolutionPreset get _activePreset => _currentMode == CameraCaptureMode.video
      ? _settingsController.videoPreset
      : _settingsController.photoPreset;

  void _handleSettingsChanged() {
    final desiredPhoto = _settingsController.photoPreset;
    final desiredVideo = _settingsController.videoPreset;
    final needsReinitialize = _currentMode == CameraCaptureMode.photo
        ? desiredPhoto != _lastAppliedPhotoPreset
        : desiredVideo != _lastAppliedVideoPreset;
    if (!needsReinitialize) {
      return;
    }
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeCamera();
  }

  Future<void> _toggleCaptureMode() async {
    if (_isRecording) {
      return;
    }
    setState(() {
      _isVideoMode = !_isVideoMode;
    });
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Web 端需要特殊处理权限
    if (kIsWeb) {
      try {
        // Web 端权限请求需要在用户手势中触发
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
        // Web 端权限 API 可能抛出异常，忽略并继续
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
      if (_cameraIndex >= _availableCameras.length) {
        _cameraIndex = 0;
      }
      final camera = _availableCameras[_cameraIndex];
      final preset = _activePreset;
      final controller = CameraController(
        camera,
        preset,
        enableAudio: _currentMode == CameraCaptureMode.video,
      );
      await controller.initialize();
      await _applyFlashMode(controller);
      final previewSize = controller.value.previewSize;
      final effectivePreview = _canvasSizeFromPreview(previewSize);
      await _profilesController.ensureCanvasSize(
        effectivePreview,
        force: true,
      );
      final resolutionInfo = previewSize == null
          ? null
          : CameraResolutionInfo(
              width: previewSize.width,
              height: previewSize.height,
            );
      if (resolutionInfo != null) {
        await _settingsController.savePreviewInfo(
          _currentMode,
          preset,
          resolutionInfo,
        );
      }
      setState(() {
        _cameraController = controller;
        _isInitialized = true;
        _lastSyncedCanvasSize = null;
        _focusIndicatorNormalized = null;
        _currentPreviewSize = effectivePreview.toSize();
      });
      if (_currentMode == CameraCaptureMode.photo) {
        _lastAppliedPhotoPreset = preset;
      } else {
        _lastAppliedVideoPreset = preset;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('相机初始化失败：$e'),
          action: SnackBarAction(
            label: '重试',
            onPressed: _initializeCamera,
          ),
        ),
      );
      return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsController.removeListener(_handleSettingsChanged);
    _focusIndicatorTimer?.cancel();
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
                tooltip: _flashLabelForMode(_flashMode),
                icon: Icon(_flashIconForMode(_flashMode)),
                onPressed: _isInitialized ? _cycleFlashMode : null,
              ),
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
                    : () async {
                        final previewSize = controller.value.previewSize;
                        final orientation = MediaQuery.of(context).orientation;
                        final effectiveSize = _effectivePreviewSize(
                          previewSize,
                          orientation,
                        );
                        final devicePixelRatio =
                            MediaQuery.of(context).devicePixelRatio;
                        final navigator = Navigator.of(context);
                        if (!kIsWeb && controller.value.isInitialized) {
                          try {
                            await controller.pausePreview();
                          } catch (error) {
                            debugPrint('pausePreview skipped: $error');
                          }
                          if (!mounted) {
                            return;
                          }
                        }
                        await navigator.pushNamed(
                          ProfileEditorScreen.routeName,
                          arguments: ProfileEditorArguments(
                            profileId: activeProfile.id,
                            bootstrapper: widget.bootstrapper,
                            fallbackCanvasSize: previewSize == null
                                ? activeProfile.canvasSize
                                : WatermarkCanvasSize(
                                    width: effectiveSize.width,
                                    height: effectiveSize.height,
                                    pixelRatio: devicePixelRatio,
                                  ),
                          ),
                        );
                        if (!mounted) {
                          return;
                        }
                        if (_isRecording || kIsWeb) {
                          return;
                        }
                        try {
                          await _cameraController?.resumePreview();
                        } catch (error) {
                          debugPrint('resumePreview skipped: $error');
                        }
                      },
              ),
              IconButton(
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    Navigator.of(context).pushNamed(SettingsScreen.routeName),
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

  // Private helper methods
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

  IconData _flashIconForMode(FlashMode mode) {
    switch (mode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.torch:
        return Icons.flashlight_on;
    }
  }

  String _flashLabelForMode(FlashMode mode) {
    switch (mode) {
      case FlashMode.auto:
        return '自动闪光';
      case FlashMode.always:
        return '闪光灯常亮';
      case FlashMode.off:
        return '闪光关闭';
      case FlashMode.torch:
        return '手电筒';
    }
  }

  Future<void> _applyFlashMode(CameraController controller) async {
    try {
      await controller.setFlashMode(_flashMode);
    } on CameraException catch (error) {
      debugPrint('apply flash mode failed: ${error.code} ${error.description}');
    } catch (error) {
      debugPrint('apply flash mode failed: $error');
    }
  }

  Future<void> _cycleFlashMode() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final modes = <FlashMode>[
      FlashMode.auto,
      FlashMode.always,
      FlashMode.off,
      FlashMode.torch,
    ];
    final currentIndex = modes.indexOf(_flashMode);
    final nextMode = modes[(currentIndex + 1) % modes.length];
    try {
      await controller.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('切换闪光灯失败：${error.description ?? error.code}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换闪光灯失败：$error')),
      );
    }
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
    final pixelRatio = mediaQuery.devicePixelRatio;
    final canvasSize = _resolveCanvasSize(
      activeProfile,
      previewSize,
      pixelRatio,
    );
    final biggest = constraints.biggest;
    final wrapperWidth =
        biggest.width.isFinite ? biggest.width : previewSize.width;
    final wrapperHeight =
        biggest.height.isFinite ? biggest.height : previewSize.height;
    final hasValidPreview = previewSize.width > 0 && previewSize.height > 0;
    final scale = hasValidPreview
        ? math.min(
            wrapperWidth / previewSize.width,
            wrapperHeight / previewSize.height,
          )
        : 1.0;
    final displayWidth =
        hasValidPreview ? previewSize.width * scale : wrapperWidth;
    final displayHeight =
        hasValidPreview ? previewSize.height * scale : wrapperHeight;
    final horizontalPadding = (wrapperWidth - displayWidth) / 2;
    final verticalPadding = (wrapperHeight - displayHeight) / 2;
    final focusOffset = _focusIndicatorNormalized == null
        ? null
        : Offset(
            horizontalPadding + _focusIndicatorNormalized!.dx * displayWidth,
            verticalPadding + _focusIndicatorNormalized!.dy * displayHeight,
          );

    return Center(
      child: SizedBox(
        width: wrapperWidth,
        height: wrapperHeight,
        child: Stack(
          children: [
            Positioned(
              left: horizontalPadding,
              top: verticalPadding,
              width: displayWidth,
              height: displayHeight,
              child: CameraPreview(controller),
            ),
            if (activeProfile != null)
              Positioned(
                left: horizontalPadding,
                top: verticalPadding,
                width: displayWidth,
                height: displayHeight,
                child: IgnorePointer(
                  ignoring: true,
                  child: WatermarkCanvasView(
                    elements: activeProfile.elements,
                    contextData: contextData,
                    canvasSize: canvasSize,
                  ),
                ),
              ),
            Positioned(
              left: horizontalPadding,
              top: verticalPadding,
              width: displayWidth,
              height: displayHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _handlePreviewTap(
                  position: details.localPosition,
                  displaySize: Size(displayWidth, displayHeight),
                ),
              ),
            ),
            if (focusOffset != null)
              Positioned(
                left: focusOffset.dx - 24,
                top: focusOffset.dy - 24,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _focusIndicatorNormalized == null ? 0 : 1,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePreviewTap({
    required Offset position,
    required Size displaySize,
  }) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final normalized = Offset(
      (position.dx / displaySize.width).clamp(0.0, 1.0),
      (position.dy / displaySize.height).clamp(0.0, 1.0),
    );
    try {
      await controller.setFocusPoint(normalized);
    } catch (error) {
      debugPrint('Set focus point failed: $error');
    }
    try {
      await controller.setExposurePoint(normalized);
    } catch (error) {
      debugPrint('Set exposure point failed: $error');
    }
    _focusIndicatorTimer?.cancel();
    setState(() {
      _focusIndicatorNormalized = normalized;
    });
    _focusIndicatorTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) {
        return;
      }
      setState(() => _focusIndicatorNormalized = null);
    });
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
                  onPressed: _toggleCaptureMode,
                ),
              ],
            ),
            if (_currentPreviewSize != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '当前预览: ${_currentPreviewSize!.width.toInt()}x${_currentPreviewSize!.height.toInt()} (${_activePreset.name})',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
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
    if (_isRecording) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('录制中无法切换摄像头')),
      );
      return;
    }
    var currentIndex = _availableCameras.indexOf(controller.description);
    if (currentIndex < 0) {
      currentIndex = _cameraIndex;
    }
    final nextIndex = (currentIndex + 1) % _availableCameras.length;
    final nextCamera = _availableCameras[nextIndex];

    setState(() {
      _isInitialized = false;
    });

    CameraController? newController;
    try {
      newController = CameraController(
        nextCamera,
        _activePreset,
        enableAudio: _currentMode == CameraCaptureMode.video,
      );
      await newController.initialize();
      await _applyFlashMode(newController);
      final previewSize = newController.value.previewSize;
      final effectivePreview = _canvasSizeFromPreview(previewSize);
      await _profilesController.ensureCanvasSize(
        effectivePreview,
        force: true,
      );
      if (previewSize != null) {
        await _settingsController.savePreviewInfo(
          _currentMode,
          _activePreset,
          CameraResolutionInfo(
            width: previewSize.width,
            height: previewSize.height,
          ),
        );
      }
      final previousController = _cameraController;
      if (!mounted) {
        await newController.dispose();
        return;
      }
      setState(() {
        _cameraIndex = nextIndex;
        _cameraController = newController;
        _isInitialized = true;
        _lastSyncedCanvasSize = null;
        _focusIndicatorNormalized = null;
        _currentPreviewSize = effectivePreview.toSize();
      });
      if (_currentMode == CameraCaptureMode.photo) {
        _lastAppliedPhotoPreset = _activePreset;
      } else {
        _lastAppliedVideoPreset = _activePreset;
      }
      await previousController?.dispose();
    } on CameraException catch (error) {
      await newController?.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitialized = controller.value.isInitialized;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('切换摄像头失败：${error.description ?? error.code}'),
        ),
      );
    } catch (error) {
      await newController?.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitialized = controller.value.isInitialized;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('切换摄像头失败：$error')));
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    final profile = _profilesController.activeProfile;
    if (controller == null || profile == null) {
      return;
    }
    final file = await controller.takePicture();
    String? mediaDataBase64;
    Uint8List? capturedBytes;
    if (kIsWeb) {
      try {
        capturedBytes = await file.readAsBytes();
        mediaDataBase64 = base64Encode(capturedBytes);
      } catch (_) {
        mediaDataBase64 = null;
      }
    }
    Size? captureSize;
    try {
      final bytes = capturedBytes ?? await file.readAsBytes();
      captureSize = await _decodeImageSize(bytes);
    } catch (_) {
      captureSize = null;
    }
    await _storeCapture(
      path: file.path,
      mediaType: WatermarkMediaType.photo,
      previewSize: controller.value.previewSize,
      captureSize: captureSize,
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
      try {
        final file = await controller.stopVideoRecording();
        setState(() => _isRecording = false);
        String? thumbnailData;
        if (!kIsWeb) {
          thumbnailData = await _generateVideoThumbnail(file.path);
        }
        await _storeCapture(
          path: file.path,
          mediaType: WatermarkMediaType.video,
          previewSize: controller.value.previewSize,
          captureSize: null,
          aspectRatio: controller.value.aspectRatio,
          profile: profile,
          thumbnailData: thumbnailData,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('视频已保存，可在图库中导出水印版本')),
        );
      } on CameraException catch (error) {
        setState(() => _isRecording = false);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('停止录像失败：${error.description ?? error.code}'),
          ),
        );
      } catch (error) {
        setState(() => _isRecording = false);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('停止录像失败：$error')),
        );
      }
    } else {
      if (!controller.value.isInitialized) {
        return;
      }
      if (!kIsWeb) {
        final micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能录制视频')),
          );
          return;
        }
      }
      try {
        await controller.prepareForVideoRecording();
      } catch (error) {
        debugPrint('prepareForVideoRecording skipped: $error');
      }
      try {
        await controller.startVideoRecording();
        setState(() => _isRecording = true);
      } on CameraException catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('开始录像失败：${error.description ?? error.code}'),
          ),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始录像失败：$error')),
        );
      }
    }
  }

  Future<String?> _generateVideoThumbnail(String videoPath) async {
    try {
      final bytes = await video_thumbnail.VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: video_thumbnail.ImageFormat.PNG,
        maxWidth: 480,
        quality: 75,
      );
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      return base64Encode(bytes);
    } catch (error) {
      debugPrint('Video thumbnail generation failed: $error');
      return null;
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

  Future<void> _storeCapture({
    required String path,
    required WatermarkMediaType mediaType,
    required Size? previewSize,
    required Size? captureSize,
    required double aspectRatio,
    required WatermarkProfile profile,
    String? mediaDataBase64,
    String? thumbnailData,
  }) async {
    final contextData = _contextController.context;
    final WatermarkCanvasSize baseCanvas;
    if (captureSize != null &&
        captureSize.width > 0 &&
        captureSize.height > 0) {
      baseCanvas = WatermarkCanvasSize(
        width: captureSize.width,
        height: captureSize.height,
        pixelRatio: WidgetsBinding
                .instance.platformDispatcher.implicitView?.devicePixelRatio ??
            1,
      );
    } else if (previewSize != null) {
      baseCanvas = _canvasSizeFromPreview(previewSize);
    } else {
      baseCanvas = _fallbackCanvasSize();
    }
    final canvasSize = profile.canvasSize ?? baseCanvas;
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

    final computedRatio = canvasSize.height == 0
        ? aspectRatio
        : canvasSize.width / canvasSize.height;

    final project = WatermarkProject(
      id: _uuid.v4(),
      mediaPath: path,
      mediaType: mediaType,
      capturedAt: DateTime.now(),
      profileId: profile.id,
      canvasSize: canvasSize,
      previewRatio: computedRatio,
      overlayPath: overlayPath,
      overlayData: overlayData,
      thumbnailData: resolvedThumbnail,
      mediaDataBase64: mediaDataBase64,
    );
    await _projectsController.addProject(project);
  }
}
