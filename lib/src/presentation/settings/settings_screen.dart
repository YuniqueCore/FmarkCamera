import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/bootstrapper.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('权限管理'),
            subtitle: const Text('管理相机、定位、存储等权限'),
            onTap: () => _openAppSettings(context),
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('启用 Impeller 渲染'),
            subtitle: const Text('推荐保持开启以获得流畅预览'),
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
  }
}
