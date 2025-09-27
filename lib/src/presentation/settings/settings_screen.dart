import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // 新增：应用设置状态
  bool _showWatermarkPreview = true;
  bool _autoSaveToGallery = true;
  String _videoQuality = 'high';
  String _exportFormat = 'auto';

  @override
  void initState() {
    super.initState();
    _settings = widget.bootstrapper.cameraSettingsController;
    _capabilitiesFuture =
        widget.bootstrapper.cameraCapabilities.loadCapabilities();
    _loadAppSettings();
  }

  // 新增：加载应用设置
  Future<void> _loadAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showWatermarkPreview = prefs.getBool('show_watermark_preview') ?? true;
      _autoSaveToGallery = prefs.getBool('auto_save_to_gallery') ?? true;
      _videoQuality = prefs.getString('video_quality') ?? 'high';
      _exportFormat = prefs.getString('export_format') ?? 'auto';
    });
  }

  // 新增：保存应用设置
  Future<void> _saveAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_watermark_preview', _showWatermarkPreview);
    await prefs.setBool('auto_save_to_gallery', _autoSaveToGallery);
    await prefs.setString('video_quality', _videoQuality);
    await prefs.setString('export_format', _exportFormat);
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
                  _buildSectionHeader('应用设置'),
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility),
                    title: const Text('显示水印预览'),
                    subtitle: const Text('在相机界面实时显示水印预览'),
                    value: _showWatermarkPreview,
                    onChanged: (value) {
                      setState(() => _showWatermarkPreview = value);
                      _saveAppSettings();
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.save),
                    title: const Text('自动保存到相册'),
                    subtitle: const Text('拍摄后自动保存到系统相册'),
                    value: _autoSaveToGallery,
                    onChanged: (value) {
                      setState(() => _autoSaveToGallery = value);
                      _saveAppSettings();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.videocam),
                    title: const Text('视频质量'),
                    subtitle: Text(_getVideoQualityLabel(_videoQuality)),
                    trailing: DropdownButton<String>(
                      value: _videoQuality,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _videoQuality = value);
                          _saveAppSettings();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('低质量')),
                        DropdownMenuItem(value: 'medium', child: Text('中等质量')),
                        DropdownMenuItem(value: 'high', child: Text('高质量')),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.image),
                    title: const Text('导出格式'),
                    subtitle: Text(_getExportFormatLabel(_exportFormat)),
                    trailing: DropdownButton<String>(
                      value: _exportFormat,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _exportFormat = value);
                          _saveAppSettings();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('自动')),
                        DropdownMenuItem(value: 'jpg', child: Text('JPEG')),
                        DropdownMenuItem(value: 'png', child: Text('PNG')),
                      ],
                    ),
                  ),
                  const Divider(),
                  _buildSectionHeader('系统设置'),
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
                      '水印配置会保存在本地文件中，导出时才会将水印合成到新的文件里。\n'
                      '所有设置更改会自动保存。',
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

  // 新增：构建章节标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 新增：获取视频质量标签
  String _getVideoQualityLabel(String quality) {
    switch (quality) {
      case 'low':
        return '低质量 (较小文件)';
      case 'medium':
        return '中等质量 (平衡大小和质量)';
      case 'high':
        return '高质量 (更大文件)';
      default:
        return '高质量';
    }
  }

  // 新增：获取导出格式标签
  String _getExportFormatLabel(String format) {
    switch (format) {
      case 'auto':
        return '自动选择最佳格式';
      case 'jpg':
        return 'JPEG (有损压缩，较小文件)';
      case 'png':
        return 'PNG (无损压缩，较大文件)';
      default:
        return '自动选择最佳格式';
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
