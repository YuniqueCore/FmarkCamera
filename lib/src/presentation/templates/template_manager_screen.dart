import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/repositories/watermark_profile_repository.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';

class TemplateManagerScreen extends StatefulWidget {
  const TemplateManagerScreen({super.key, required this.bootstrapper});

  static const String routeName = '/templates';
  final Bootstrapper bootstrapper;

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  final Uuid _uuid = const Uuid();
  late final WatermarkProfileRepository _repository;
  List<WatermarkProfile> _profiles = const <WatermarkProfile>[];
  String? _activeProfileId;
  bool _initialized = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.bootstrapper.profileRepository;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as TemplateManagerArguments?;
    _activeProfileId = args?.activeProfileId;
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _repository.loadProfiles();
    setState(() {
      _profiles = profiles;
      _loading = false;
      _activeProfileId = _activeProfileId ??
          profiles
              .firstWhere(
                (profile) => profile.isDefault,
                orElse: () => profiles.isNotEmpty ? profiles.first : null,
              )
              .id;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('水印模板管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: () async {
              await _repository.saveProfiles(_profiles);
              if (!mounted) {
                return;
              }
              Navigator.of(context).pop(
                _profiles.firstWhere(
                  (profile) => profile.id == _activeProfileId,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_outlined),
            onPressed: _createTemplate,
          ),
        ],
      ),
      body: ReorderableListView.builder(
        itemCount: _profiles.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          setState(() {
            final profile = _profiles.removeAt(oldIndex);
            _profiles.insert(newIndex, profile);
          });
        },
        itemBuilder: (context, index) {
          final profile = _profiles[index];
          final selected = profile.id == _activeProfileId;
          return Card(
            key: ValueKey(profile.id),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(profile.name),
              subtitle: Text('元素 ${profile.elements.length} 个'),
              trailing: selected
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () => setState(() => _activeProfileId = profile.id),
              onLongPress: () => _renameProfile(profile),
            ),
          );
        },
      ),
    );
  }

  Future<void> _renameProfile(WatermarkProfile profile) async {
    final controller = TextEditingController(text: profile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名模板'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '模板名称'),
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
        );
      },
    );
    if (result == null || result.isEmpty) {
      return;
    }
    setState(() {
      _profiles = _profiles
          .map(
            (item) => item.id == profile.id
                ? item.copyWith(name: result, updatedAt: DateTime.now())
                : item,
          )
          .toList();
    });
  }

  void _createTemplate() {
    final profile = WatermarkProfile(
      id: _uuid.v4(),
      name: '新模板${_profiles.length + 1}',
      elements: const <WatermarkElement>[],
      updatedAt: DateTime.now(),
    );
    setState(() => _profiles = [..._profiles, profile]);
  }
}

class TemplateManagerArguments {
  const TemplateManagerArguments({required this.activeProfileId});

  final String activeProfileId;
}
