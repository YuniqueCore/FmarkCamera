import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/watermark_profiles_controller.dart';

import 'package:fmark_camera/src/presentation/profiles/profile_editor_screen.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key, required this.bootstrapper});

  static const String routeName = '/profiles';

  final Bootstrapper bootstrapper;

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late final WatermarkProfilesController _profilesController;

  @override
  void initState() {
    super.initState();
    _profilesController = widget.bootstrapper.profilesController;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _profilesController,
      builder: (context, _) {
        final profiles = _profilesController.profiles;
        return Scaffold(
          appBar: AppBar(
            title: const Text('水印 Profile 管理'),
            actions: [
              IconButton(
                onPressed: () => _createProfile(context),
                icon: const Icon(Icons.add_outlined),
                tooltip: '新建 Profile',
              ),
            ],
          ),
          body: profiles.isEmpty
              ? _buildEmptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final isActive =
                        _profilesController.activeProfile?.id == profile.id;
                    return ListTile(
                      title: Text(profile.name),
                      subtitle: Text('${profile.elements.length} 个元素'),
                      leading: Icon(
                        isActive
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        await _profilesController.setActive(profile.id);
                        navigator.pop(profile);
                      },
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: '编辑',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openEditor(profile),
                          ),
                          IconButton(
                            tooltip: '复制',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () => _duplicateProfile(profile),
                          ),
                          IconButton(
                            tooltip: '删除',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteProfile(profile),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          bottomNavigationBar: profiles.isEmpty
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _setDefault(context),
                            icon: const Icon(Icons.star_outlined),
                            label: const Text('设为默认'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              final active = _profilesController
                                      .activeProfile ??
                                  (profiles.isNotEmpty ? profiles.first : null);
                              if (active != null) {
                                _renameProfile(context, active);
                              }
                            },
                            icon: const Icon(Icons.drive_file_rename_outline),
                            label: const Text('重命名'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_outlined, size: 64, color: Colors.white54),
          const SizedBox(height: 12),
          const Text('尚未创建任何水印 Profile'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _createProfile(context),
            child: const Text('立即创建'),
          ),
        ],
      ),
    );
  }

  Future<void> _createProfile(BuildContext context) async {
    final name = await _promptForText(
      context,
      title: '新建 Profile',
      label: '名称',
      initialValue: '水印模板 ${_profilesController.profiles.length + 1}',
    );
    if (name == null || name.isEmpty) {
      return;
    }
    final template = _profilesController.activeProfile;
    final canvasSize = template?.canvasSize ??
        const WatermarkCanvasSize(width: 1080, height: 1920);
    final uuid = const Uuid();
    await _profilesController.createProfile(
      id: uuid.v4(),
      name: name,
      canvasSize: canvasSize,
    );
  }

  Future<void> _duplicateProfile(WatermarkProfile profile) async {
    final name = await _promptForText(
      context,
      title: '复制 Profile',
      label: '新名称',
      initialValue: '${profile.name} 副本',
    );
    if (name == null || name.isEmpty) {
      return;
    }
    final uuid = const Uuid();
    await _profilesController.duplicateProfile(
      source: profile,
      newId: uuid.v4(),
      newName: name,
    );
  }

  Future<void> _renameProfile(
    BuildContext context,
    WatermarkProfile profile,
  ) async {
    final name = await _promptForText(
      context,
      title: '重命名 Profile',
      label: '名称',
      initialValue: profile.name,
    );
    if (name == null || name.isEmpty || name == profile.name) {
      return;
    }
    await _profilesController.renameProfile(profile.id, name);
  }

  Future<void> _deleteProfile(WatermarkProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${profile.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    await _profilesController.deleteProfile(profile.id);
  }

  Future<void> _setDefault(BuildContext context) async {
    final profile = _profilesController.activeProfile;
    if (profile == null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    await _profilesController.setDefaultProfile(profile.id);
    messenger.showSnackBar(
      SnackBar(content: Text('${profile.name} 已设为默认水印')),
    );
  }

  Future<String?> _promptForText(
    BuildContext context, {
    required String title,
    required String label,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openEditor(WatermarkProfile profile) async {
    await Navigator.of(context).pushNamed(
      ProfileEditorScreen.routeName,
      arguments: ProfileEditorArguments(
        profileId: profile.id,
        bootstrapper: widget.bootstrapper,
      ),
    );
  }
}
