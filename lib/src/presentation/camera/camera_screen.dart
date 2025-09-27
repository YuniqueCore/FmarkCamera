import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
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
import 'package:fmark_camera/src/services/camera_capabilities_service.dart';
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
  bool _isInitializing = false;
  Size? _lastSyncedCanvasSize;
  Size? _currentPreviewSize;
  CameraResolutionInfo? _currentCaptureInfo;
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
  late final CameraCapabilitiesService _capabilitiesService;

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
    _capabilitiesService = bootstrapper.cameraCapabilities;
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
    if (_isRecording || _isInitializing) {
      return;
    }
    setState(() {
      _isVideoMode = !_isVideoMode;
    });
    await _initializeCamera();
  }

  Future<void> _initializeCamera({int? forcedIndex}) async {
    if (_isInitializing) {
      return;
    }
    _isInitializing = true;
    try {
      final hasPermission = await _ensureCameraPermission();
      if (!hasPermission) {
        return;
      }

      if (_availableCameras.isEmpty) {
        _availableCameras = await availableCameras();
      } else {
        try {
          _availableCameras = await availableCameras();
        } catch (error) {
          debugPrint('availableCameras refresh failed: $error');
        }
      }
      if (_availableCameras.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到可用的相机')),
        );
        return;
      }

      if (forcedIndex != null && forcedIndex >= 0) {
        _cameraIndex = forcedIndex % _availableCameras.length;
      } else if (_cameraIndex >= _availableCameras.length) {
        _cameraIndex = 0;
      }
      final camera = _availableCameras[_cameraIndex];
      final preset = _activePreset;

      final previousController = _cameraController;
      if (mounted) {
        setState(() {
          _cameraController = null;
          _isInitialized = false;
        });
      } else {
        _cameraController = null;
        _isInitialized = false;
      }
      try {
        await previousController?.dispose();
      } catch (error) {
        debugPrint('dispose previous controller failed: $error');
      }

      final capabilities = await _capabilitiesService.findById(camera.name);
      final preferredSelection =
          _settingsController.resolutionForMode(_currentMode);
      final captureInfo = _selectCaptureInfo(
        capabilities: capabilities,
        preset: preset,
        mode: _currentMode,
        preferred: preferredSelection,
      );

      final controller = CameraController(
        camera,
        preset,
        enableAudio: _currentMode == CameraCaptureMode.video,
      );
      await controller.initialize();
      await _applyFlashMode(controller);

      final previewSize = controller.value.previewSize;
      final matchedActual = _matchCaptureSize(
        capabilities: capabilities,
        mode: _currentMode,
        previewSize: previewSize,
      );
      final resolvedCapture =
          matchedActual ?? captureInfo ?? preferredSelection;
      final canvasSize = resolvedCapture == null
          ? _canvasSizeFromPreview(previewSize)
          : _canvasSizeFromCaptureInfo(resolvedCapture);

      await _profilesController.ensureCanvasSize(
        canvasSize,
        force: true,
      );

      if (previewSize != null) {
        await _settingsController.savePreviewInfo(
          mode: _currentMode,
          preset: preset,
          info: CameraResolutionInfo(
            width: previewSize.width,
            height: previewSize.height,
          ),
          cameraId: camera.name,
          capture: resolvedCapture,
          lensFacing: capabilities?.lensFacing,
        );
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isInitialized = true;
        _lastSyncedCanvasSize = null;
        _focusIndicatorNormalized = null;
        _currentPreviewSize = canvasSize.toSize();
        _currentCaptureInfo = resolvedCapture;
      });

      if (_currentMode == CameraCaptureMode.photo) {
        _lastAppliedPhotoPreset = preset;
      } else {
        _lastAppliedVideoPreset = preset;
      }
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('相机初始化失败：${error.description ?? error.code}'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () => _initializeCamera(forcedIndex: forcedIndex),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('相机初始化失败：$error'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () => _initializeCamera(forcedIndex: forcedIndex),
          ),
        ),
      );
    } finally {
      _isInitializing = false;
    }
  }

  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) {
      try {
        final permission = await Permission.camera.request();
        if (permission.isGranted) {
          return true;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要相机权限才能使用此功能')),
          );
        }
        return false;
      } catch (error) {
        debugPrint('Web camera permission check: $error');
        return true;
      }
    }
    final permission = await Permission.camera.request();
    if (permission.isGranted) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要相机权限才能使用此功能')),
      );
    }
    return false;
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
  WatermarkCanvasSize _fallbackCanvasSize() {
    final fallback = _platformViewportFallback();
    return WatermarkCanvasSize(width: fallback.width, height: fallback.height);
  }

  double _devicePixelRatio() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final views = dispatcher.views;
    if (views.isNotEmpty) {
      return views.first.devicePixelRatio;
    }
    return dispatcher.implicitView?.devicePixelRatio ?? 1;
  }

  WatermarkCanvasSize _canvasSizeFromPreview(Size? previewSize) {
    final size = previewSize ?? _fallbackCanvasSize().toSize();
    final normalized = _normalizeViewportSize(size);
    return WatermarkCanvasSize(
      width: normalized.width,
      height: normalized.height,
      pixelRatio: _devicePixelRatio(),
    );
  }

  WatermarkCanvasSize _canvasSizeFromCaptureInfo(
    CameraResolutionInfo info,
  ) {
    final normalized = _normalizeViewportSize(Size(info.width, info.height));
    return WatermarkCanvasSize(
      width: normalized.width,
      height: normalized.height,
      pixelRatio: _devicePixelRatio(),
    );
  }

  Size _platformViewportFallback() {
    return kIsWeb ? const Size(1920, 1080) : const Size(1080, 1920);
  }

  Size _normalizeViewportSize(Size size) {
    if (kIsWeb) {
      return size.width >= size.height ? size : Size(size.height, size.width);
    }
    return size.height >= size.width ? size : Size(size.height, size.width);
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
    final previewSize = controller.value.previewSize;
    final captureInfo = _currentCaptureInfo;
    final normalizedCapture = captureInfo == null
        ? null
        : _normalizeViewportSize(Size(captureInfo.width, captureInfo.height));
    final normalizedPreview = previewSize == null
        ? null
        : _normalizeViewportSize(previewSize);
    final targetSize = normalizedCapture ?? normalizedPreview ?? _platformViewportFallback();
    final pixelRatio = mediaQuery.devicePixelRatio;
    final canvasSize = _resolveCanvasSize(
      activeProfile,
      targetSize,
      pixelRatio,
    );

    return Center(
      child: AspectRatio(
        aspectRatio: targetSize.width / targetSize.height,
        child: LayoutBuilder(
          builder: (context, viewport) {
            final viewportSize = Size(viewport.maxWidth, viewport.maxHeight);
            final focusOffset = _focusIndicatorNormalized == null
                ? null
                : Offset(
                    _focusIndicatorNormalized!.dx * viewportSize.width,
                    _focusIndicatorNormalized!.dy * viewportSize.height,
                  );
            final previewSourceSize = normalizedPreview ?? targetSize;
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: previewSourceSize.width,
                      height: previewSourceSize.height,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
                if (activeProfile != null)
                  IgnorePointer(
                    ignoring: true,
                    child: WatermarkCanvasView(
                      elements: activeProfile.elements,
                      contextData: contextData,
                      canvasSize: canvasSize,
                    ),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _handlePreviewTap(
                      position: details.localPosition,
                      displaySize: viewportSize,
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
            );
          },
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
    final orientation = MediaQuery.of(context).orientation;

    // 优先使用捕获尺寸，确保水印画布与实际拍照/录像分辨率一致
    final baseSize = _currentCaptureInfo != null
        ? Size(_currentCaptureInfo!.width, _currentCaptureInfo!.height)
        : controller.value.previewSize;

    if (baseSize == null || !mounted) {
      return;
    }

    // 计算有效显示尺寸，保持正确的宽高比
    final effective = _effectivePreviewSize(baseSize, orientation);

    // 检查是否需要更新画布尺寸
    if (_lastSyncedCanvasSize != null) {
      final last = _lastSyncedCanvasSize!;
      // 使用更宽松的容差来避免频繁更新
      if ((last.width - effective.width).abs() < 1.0 &&
          (last.height - effective.height).abs() < 1.0) {
        return;
      }
    }

    _lastSyncedCanvasSize = effective;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      // 使用捕获分辨率作为画布尺寸，确保水印位置与实际输出一致
      final captureSize = _currentCaptureInfo != null
          ? Size(_currentCaptureInfo!.width, _currentCaptureInfo!.height)
          : effective;

      _profilesController.ensureCanvasSize(
        WatermarkCanvasSize(
          width: captureSize.width,
          height: captureSize.height,
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
    return _normalizeViewportSize(previewSize);
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
    final aspectDiff = (candidateAspect - fallbackAspect).abs();
    if (aspectDiff <= 0.02) {
      return candidate.copyWith(pixelRatio: pixelRatio);
    }
    final swappedAspect = candidate.height <= 0
        ? candidateAspect
        : candidate.height / candidate.width;
    if ((swappedAspect - fallbackAspect).abs() <= 0.02) {
      return WatermarkCanvasSize(
        width: candidate.height,
        height: candidate.width,
        pixelRatio: pixelRatio,
      );
    }
    return WatermarkCanvasSize(
      width: fallback.width,
      height: fallback.height,
      pixelRatio: pixelRatio,
    );
  }

  Widget _buildBottomBar(WatermarkProfile? activeProfile) {
    final controller = _cameraController;
    final profiles = _profilesController.profiles;
    final activeId = activeProfile?.id;
    final captureInfo = _currentCaptureInfo;
    final previewSize = _currentPreviewSize;
    final modeLabel = _currentMode == CameraCaptureMode.photo ? '照片' : '视频';
    final infoText = captureInfo != null
        ? '当前捕获：${captureInfo.width.toInt()}x${captureInfo.height.toInt()} ($modeLabel)'
        : previewSize != null
            ? '当前预览：${previewSize.width.toInt()}x${previewSize.height.toInt()} (${_activePreset.name})'
            : null;

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
            if (infoText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  infoText,
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
    if (_availableCameras.length < 2 || _isRecording || _isInitializing) {
      return;
    }
    final controller = _cameraController;
    int nextIndex;
    if (controller == null || !controller.value.isInitialized) {
      nextIndex = (_cameraIndex + 1) % _availableCameras.length;
    } else {
      final currentIndex = _availableCameras.indexOf(controller.description);
      nextIndex = currentIndex < 0
          ? (_cameraIndex + 1) % _availableCameras.length
          : (currentIndex + 1) % _availableCameras.length;
    }
    await _initializeCamera(forcedIndex: nextIndex);
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
      if (captureSize != null &&
          captureSize.width > 0 &&
          captureSize.height > 0) {
        if (captureSize.width > captureSize.height) {
          captureSize = Size(captureSize.height, captureSize.width);
        }
      }
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
      // 停止录像
      try {
        final file = await controller.stopVideoRecording();
        setState(() => _isRecording = false);

        // 验证视频文件
        if (!kIsWeb &&
            await File(file.path).exists() &&
            await File(file.path).length() > 0) {
          final thumbnailData = await _generateVideoThumbnail(file.path);

          await _storeCapture(
            path: file.path,
            mediaType: WatermarkMediaType.video,
            previewSize: controller.value.previewSize,
            captureSize: _currentCaptureInfo?.toSize(),
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
        } else {
          // 视频文件无效
          setState(() => _isRecording = false);
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('录制的视频文件无效')),
          );
        }
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
        debugPrint('Stop video recording error: $error');
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('停止录像失败：$error')),
        );
      }
    } else {
      // 开始录像
      if (!controller.value.isInitialized) {
        return;
      }

      // 检查麦克风权限（Android 需要）
      if (!kIsWeb) {
        try {
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
        } catch (error) {
          debugPrint('Microphone permission check failed: $error');
          // 继续尝试录像，即使权限检查失败
        }
      }

      try {
        // 准备视频录制
        try {
          await controller.prepareForVideoRecording();
        } catch (error) {
          debugPrint(
              'prepareForVideoRecording failed, continuing anyway: $error');
        }

        // 开始录制
        await controller.startVideoRecording();
        setState(() => _isRecording = true);

        debugPrint('Video recording started successfully');
      } on CameraException catch (error) {
        debugPrint(
            'Start video recording CameraException: ${error.code} - ${error.description}');
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('开始录像失败：${error.description ?? error.code}'),
          ),
        );
      } catch (error) {
        debugPrint('Start video recording error: $error');
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
    final Size? normalizedCapture =
        captureSize ?? _currentCaptureInfo?.toSize();

    WatermarkCanvasSize baseCanvas;
    if (normalizedCapture != null &&
        normalizedCapture.width > 0 &&
        normalizedCapture.height > 0) {
      baseCanvas = WatermarkCanvasSize(
        width: normalizedCapture.width,
        height: normalizedCapture.height,
        pixelRatio: _devicePixelRatio(),
      );
    } else if (previewSize != null) {
      baseCanvas = _canvasSizeFromPreview(previewSize);
    } else {
      baseCanvas = _fallbackCanvasSize();
    }
    final WatermarkCanvasSize canvasSize;
    final candidate = profile.canvasSize;
    if (candidate == null || candidate.width <= 0 || candidate.height <= 0) {
      canvasSize = baseCanvas;
    } else {
      final aspectDiff = (candidate.width / candidate.height) -
          (baseCanvas.width / baseCanvas.height);
      if (aspectDiff.abs() <= 0.02) {
        canvasSize = candidate;
      } else {
        final swappedCandidate = WatermarkCanvasSize(
          width: candidate.height,
          height: candidate.width,
          pixelRatio: candidate.pixelRatio,
        );
        final swappedDiff = (swappedCandidate.width / swappedCandidate.height) -
            (baseCanvas.width / baseCanvas.height);
        canvasSize = swappedDiff.abs() <= 0.02 ? swappedCandidate : baseCanvas;
      }
    }
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

CameraResolutionInfo? _matchCaptureSize({
  required CameraDeviceCapabilities? capabilities,
  required CameraCaptureMode mode,
  required Size? previewSize,
}) {
  if (capabilities == null || previewSize == null) {
    return null;
  }
  final sizes = mode == CameraCaptureMode.photo
      ? capabilities.photoSizes
      : capabilities.videoSizes;
  if (sizes.isEmpty) {
    return null;
  }
  final target = CameraResolutionInfo(
    width: previewSize.width,
    height: previewSize.height,
  ).toPortrait();
  CameraResolutionInfo? best;
  double bestScore = double.infinity;
  for (final candidate in sizes) {
    final canonical = candidate.toPortrait();
    final aspectDiff = (canonical.aspectRatio - target.aspectRatio).abs();
    final pixelDiff = (canonical.pixelCount - target.pixelCount).abs();
    final score = aspectDiff * 5 + pixelDiff / 1000000;
    if (score < bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return best;
}

CameraResolutionInfo? _selectCaptureInfo({
  required CameraDeviceCapabilities? capabilities,
  required ResolutionPreset preset,
  required CameraCaptureMode mode,
  CameraResolutionInfo? preferred,
}) {
  final sizes = mode == CameraCaptureMode.photo
      ? capabilities?.photoSizes
      : capabilities?.videoSizes;

  if (sizes == null || sizes.isEmpty) {
    return preferred;
  }

  // 改进分辨率选择逻辑
  switch (preset) {
    case ResolutionPreset.max:
      return sizes.first; // 返回最高分辨率

    case ResolutionPreset.ultraHigh:
      // 分辨率：宽*高
      // 寻找 4K 分辨率（2160*3840 或 2448*3264）
      // 分辨率应该是 3:4 或者 9/16
      return _pickResolution(
            sizes,
            minHeight: 3840,
            minWidth: 2160,
            preferredAspect: 16 / 9,
          ) ??
          _pickResolution(
            sizes,
            minHeight: 3264,
            minWidth: 2448,
            preferredAspect: 4 / 3,
          ) ??
          _pickResolution(
            sizes,
            minHeight: 3000,
            minWidth: 2000,
          ) ??
          sizes.first;

    case ResolutionPreset.veryHigh:
      // 寻找 1080p 分辨率
      return _pickResolution(
            sizes,
            minHeight: 1920,
            minWidth: 1080,
            preferredAspect: 16 / 9,
          ) ??
          _pickResolution(
            sizes,
            minHeight: 1800,
            minWidth: 1000,
          ) ??
          sizes.first;

    case ResolutionPreset.high:
      // 寻找 720p 分辨率
      return _pickResolution(
            sizes,
            minHeight: 1280,
            minWidth: 720,
            preferredAspect: 16 / 9,
          ) ??
          _pickResolution(
            sizes,
            minHeight: 1200,
            minWidth: 700,
          ) ??
          sizes.first;

    case ResolutionPreset.medium:
      // 寻找 480p 分辨率
      return _pickResolution(
            sizes,
            minHeight: 720,
            minWidth: 480,
            preferredAspect: 3 / 2,
          ) ??
          _pickResolution(
            sizes,
            minHeight: 640,
            minWidth: 480,
          ) ??
          sizes.first;

    case ResolutionPreset.low:
      return sizes.last; // 返回最低分辨率
  }
}

CameraResolutionInfo? _pickResolution(
  List<CameraResolutionInfo> sizes, {
  double? minWidth,
  double? minHeight,
  double? minPixels,
  double? preferredAspect,
}) {
  for (final size in sizes) {
    if (minWidth != null && size.width < minWidth) {
      continue;
    }
    if (minHeight != null && size.height < minHeight) {
      continue;
    }
    if (minPixels != null && size.pixelCount < minPixels) {
      continue;
    }
    if (preferredAspect != null &&
        !_isAspectClose(size.aspectRatio, preferredAspect)) {
      continue;
    }
    return size;
  }
  if (preferredAspect != null) {
    for (final size in sizes) {
      if (_isAspectClose(size.aspectRatio, preferredAspect)) {
        return size;
      }
    }
  }
  return null;
}

bool _isAspectClose(double value, double target) {
  return (value - target).abs() < 0.12;
}
