import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:fmark_camera/src/domain/models/camera_resolution_info.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/camera_settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.bootstrapper});

  static const String routeName = '/settings';
  final Bootstrapper bootstrapper;

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
    final settings = bootstrapper.cameraSettingsController;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            children: [
              _buildResolutionTile(
                context: context,
                controller: settings,
                mode: CameraCaptureMode.photo,
              ),
              _buildResolutionTile(
                context: context,
                controller: settings,
                mode: CameraCaptureMode.video,
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
          ),
        );
      },
    );
  }

  Widget _buildResolutionTile({
    required BuildContext context,
    required CameraSettingsController controller,
    required CameraCaptureMode mode,
  }) {
    final title = mode == CameraCaptureMode.photo ? '照片分辨率' : '视频分辨率';
    final leadingIcon = mode == CameraCaptureMode.photo
        ? Icons.photo_camera_outlined
        : Icons.videocam_outlined;
    final selectedPreset = controller.presetForMode(mode);
    final selectedInfo = controller.previewInfo(mode, selectedPreset);
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
              await controller.setPhotoPreset(value);
            } else {
              await controller.setVideoPreset(value);
            }
          },
          items: ResolutionPreset.values
              .map(
                (preset) => DropdownMenuItem<ResolutionPreset>(
                  value: preset,
                  child: Text(
                    _resolutionSubtitle(
                      preset,
                      controller.previewInfo(mode, preset),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
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
}
