import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:fmark_camera/src/domain/models/camera_resolution_info.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/camera_capabilities_service.dart';
import 'package:fmark_camera/src/services/camera_settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.bootstrapper});

  static const String routeName = '/settings';

  final Bootstrapper bootstrapper;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final CameraSettingsController _settings;
  late final Future<List<CameraDeviceCapabilities>> _capabilitiesFuture;

  @override
  void initState() {
    super.initState();
    _settings = widget.bootstrapper.cameraSettingsController;
    _capabilitiesFuture =
        widget.bootstrapper.cameraCapabilities.loadCapabilities();
  }

  Future<void> _openAppSettings(BuildContext context) async {
    final opened = await openAppSettings();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(opened ? '已打开系统设置' : '无法打开设置')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: FutureBuilder<List<CameraDeviceCapabilities>>(
            future: _capabilitiesFuture,
            builder: (context, snapshot) {
              final capabilities =
                  snapshot.data ?? const <CameraDeviceCapabilities>[];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                      capabilities.isEmpty;
              return ListView(
                children: [
                  _buildResolutionTile(
                    context: context,
                    mode: CameraCaptureMode.photo,
                    capabilities: capabilities,
                    isLoading: isLoading,
                  ),
                  _buildResolutionTile(
                    context: context,
                    mode: CameraCaptureMode.video,
                    capabilities: capabilities,
                    isLoading: isLoading,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: const Text('权限管理'),
                    subtitle: const Text('管理相机、定位、存储等权限'),
                    onTap: () => _openAppSettings(context),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '水印配置会保存在本地文件中，导出时才会将水印合成到新的文件里。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildResolutionTile({
    required BuildContext context,
    required CameraCaptureMode mode,
    required List<CameraDeviceCapabilities> capabilities,
    required bool isLoading,
  }) {
    final title = mode == CameraCaptureMode.photo ? '照片分辨率' : '视频分辨率';
    final leadingIcon = mode == CameraCaptureMode.photo
        ? Icons.photo_camera_outlined
        : Icons.videocam_outlined;

    if (isLoading) {
      return ListTile(
        leading: Icon(leadingIcon),
        title: Text(title),
        subtitle: const Text('正在读取设备能力…'),
        trailing: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final options = _buildOptions(capabilities, mode);
    if (options.isEmpty) {
      return _buildPresetFallback(context: context, mode: mode);
    }

    final selection = _settings.selectionForMode(mode);
    _ResolutionOption selected = options.first;
    if (selection != null) {
      final matched = options.where(
        (option) => option.matches(selection),
      );
      if (matched.isNotEmpty) {
        selected = matched.first;
      }
    }

    return ListTile(
      leading: Icon(leadingIcon),
      title: Text(title),
      subtitle: Text(_formatOptionSubtitle(selected)),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<_ResolutionOption>(
          value: selected,
          isExpanded: true,
          items: options
              .map(
                (option) => DropdownMenuItem<_ResolutionOption>(
                  value: option,
                  child: Text(_formatOptionLabel(option)),
                ),
              )
              .toList(),
          onChanged: (option) async {
            if (option == null) {
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
            await _settings.setResolutionSelection(
              mode: mode,
              selection: CameraResolutionSelection(
                resolution: option.info,
                preset: option.preset,
                cameraId: option.cameraId,
                lensFacing: option.lensFacing,
              ),
            );
            await widget.bootstrapper.profilesController.ensureCanvasSize(
              WatermarkCanvasSize(
                width: option.info.width,
                height: option.info.height,
                pixelRatio: devicePixelRatio,
              ),
              force: true,
              tolerance: 0.02,
            );
            if (!mounted) {
              return;
            }
            messenger.showSnackBar(
              SnackBar(content: Text('$title已更新为 ${_formatOptionLabel(option)}')),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPresetFallback({
    required BuildContext context,
    required CameraCaptureMode mode,
  }) {
    final title = mode == CameraCaptureMode.photo ? '照片分辨率' : '视频分辨率';
    final leadingIcon = mode == CameraCaptureMode.photo
        ? Icons.photo_camera_outlined
        : Icons.videocam_outlined;
    final selectedPreset = _settings.presetForMode(mode);
    final selectedInfo = _settings.previewInfo(mode, selectedPreset);
    return ListTile(
      leading: Icon(leadingIcon),
      title: Text(title),
      subtitle: Text(_resolutionSubtitle(selectedPreset, selectedInfo)),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<ResolutionPreset>(
          value: selectedPreset,
          onChanged: (value) async {
            if (value == null) {
              return;
            }
            if (mode == CameraCaptureMode.photo) {
              await _settings.setPhotoPreset(value);
            } else {
              await _settings.setVideoPreset(value);
            }
          },
          items: ResolutionPreset.values
              .map(
                (preset) => DropdownMenuItem<ResolutionPreset>(
                  value: preset,
                  child: Text(
                    _resolutionSubtitle(
                      preset,
                      _settings.previewInfo(mode, preset),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  List<_ResolutionOption> _buildOptions(
    List<CameraDeviceCapabilities> capabilities,
    CameraCaptureMode mode,
  ) {
    final options = <_ResolutionOption>[];
    for (final device in capabilities) {
      final sizes =
          mode == CameraCaptureMode.photo ? device.photoSizes : device.videoSizes;
      if (sizes.isEmpty) {
        continue;
      }
      final sorted = [...sizes]
        ..sort(
          (a, b) => b.pixelCount.compareTo(a.pixelCount),
        );
      for (var index = 0; index < sorted.length; index++) {
        final info = sorted[index];
        final preset = index == 0
            ? ResolutionPreset.max
            : _presetForResolution(info);
        options.add(
          _ResolutionOption(
            info: info,
            preset: preset,
            cameraId: device.cameraId,
            lensFacing: device.lensFacing,
          ),
        );
      }
    }
    options.sort((a, b) => b.info.pixelCount.compareTo(a.info.pixelCount));
    return options;
  }

  String _formatOptionLabel(_ResolutionOption option) {
    final resolution = option.info;
    final aspect = _formatAspectRatio(resolution.aspectRatio);
    final lensLabel = _lensFacingLabel(option.lensFacing);
    final segments = <String>[
      '${resolution.width.toStringAsFixed(0)}x${resolution.height.toStringAsFixed(0)}',
      if (aspect != null) aspect,
      if (lensLabel != null) lensLabel,
    ];
    return segments.join(' · ');
  }

  String _formatOptionSubtitle(_ResolutionOption option) {
    final presetLabel = resolutionPresetLabel(option.preset);
    return '$presetLabel · ${_formatOptionLabel(option)}';
  }

  String _resolutionSubtitle(
    ResolutionPreset preset,
    CameraResolutionInfo? info,
  ) {
    final label = resolutionPresetLabel(preset);
    if (info == null || !info.isValid) {
      return label;
    }
    return '$label · ${info.width.toStringAsFixed(0)}x${info.height.toStringAsFixed(0)}';
  }

  ResolutionPreset _presetForResolution(CameraResolutionInfo info) {
    final largerSide = math.max(info.width, info.height);
    final pixels = info.pixelCount;
    if (largerSide >= 3840 || pixels >= 3840 * 2160) {
      return ResolutionPreset.ultraHigh;
    }
    if (largerSide >= 2560 || pixels >= 2560 * 1440) {
      return ResolutionPreset.veryHigh;
    }
    if (largerSide >= 1920 || pixels >= 1920 * 1080) {
      return ResolutionPreset.high;
    }
    if (largerSide >= 1280 || pixels >= 1280 * 720) {
      return ResolutionPreset.medium;
    }
    return ResolutionPreset.low;
  }

  String? _formatAspectRatio(double ratio) {
    const known = <String, double>{
      '16:9': 16 / 9,
      '4:3': 4 / 3,
      '3:2': 3 / 2,
      '1:1': 1,
    };
    for (final entry in known.entries) {
      if ((ratio - entry.value).abs() < 0.02) {
        return entry.key;
      }
    }
    return ratio > 0 ? ratio.toStringAsFixed(2) : null;
  }

  String? _lensFacingLabel(String? lensFacing) {
    if (lensFacing == null) {
      return null;
    }
    switch (lensFacing.toLowerCase()) {
      case 'back':
      case 'rear':
        return '后摄';
      case 'front':
        return '前摄';
      case 'external':
        return '外接镜头';
      default:
        return lensFacing;
    }
  }
}

class _ResolutionOption {
  const _ResolutionOption({
    required this.info,
    required this.preset,
    required this.cameraId,
    required this.lensFacing,
  });

  final CameraResolutionInfo info;
  final ResolutionPreset preset;
  final String cameraId;
  final String? lensFacing;

  bool matches(CameraResolutionSelection selection) {
    final sameCamera = selection.cameraId == null ||
        selection.cameraId == cameraId;
    return sameCamera &&
        selection.resolution.approximatelyEquals(info, tolerance: 2.0);
  }
}
