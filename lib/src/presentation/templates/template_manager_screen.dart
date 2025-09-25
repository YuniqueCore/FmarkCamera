import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/repositories/watermark_profile_repository.dart';
import 'package:fmark_camera/src/presentation/templates/watermark_profile_editor_screen.dart';
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
  WatermarkCanvasSize? _cameraCanvas;
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
    _cameraCanvas = args?.cameraCanvas;
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _repository.loadProfiles();
    List<WatermarkProfile> normalized = profiles;
    if (_cameraCanvas != null) {
      bool changed = false;
      normalized = profiles
          .map((profile) => profile.canvasSize == null
              ? (() {
                  changed = true;
                  return profile.copyWith(
                    canvasSize: _cameraCanvas,
                    updatedAt: DateTime.now(),
                  );
                })()
              : profile)
          .toList();
      if (changed) {
        await _repository.saveProfiles(normalized);
      }
    }
    setState(() {
      _profiles = normalized;
      _loading = false;
      if (_activeProfileId == null && normalized.isNotEmpty) {
        final selected = normalized.firstWhere(
          (profile) => profile.isDefault,
          orElse: () => normalized.first,
        );
        _activeProfileId = selected.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final active = _profiles.firstWhere(
        (profile) => profile.id == _activeProfileId,
        orElse: () => _profiles.first);
    return Scaffold(
      appBar: AppBar(
        title: const Text('水印模板管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_outlined),
            tooltip: '新建模板',
            onPressed: _createTemplate,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存并返回',
            onPressed: () {
              final current = _profiles.firstWhere(
                (profile) => profile.id == _activeProfileId,
                orElse: () => _profiles.first,
              );
              _repository.saveProfiles(_profiles);
              Navigator.of(context).pop(current);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit_outlined),
        label: const Text('编辑画布'),
        onPressed: () => _openEditor(active),
      ),
      body: Column(
        children: [
          _buildProfileCarousel(active.id),
          const Divider(height: 1),
          Expanded(child: _buildProfileDetail(active)),
        ],
      ),
    );
  }

  Widget _buildProfileCarousel(String activeId) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final profile = _profiles[index];
          final selected = profile.id == activeId;
          return GestureDetector(
            onTap: () => setState(() => _activeProfileId = profile.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: selected
                    ? Colors.orangeAccent.withValues(alpha: 0.25)
                    : Colors.white10,
                border: Border.all(
                  color: selected ? Colors.orangeAccent : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          profile.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!profile.isDefault)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _deleteProfile(profile),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${profile.elements.length} 个元素',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? Colors.orangeAccent : Colors.white38,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemCount: _profiles.length,
      ),
    );
  }

  Widget _buildProfileDetail(WatermarkProfile profile) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        ListTile(
          title: Text(profile.name),
          subtitle: Text('元素 ${profile.elements.length} 个'),
          trailing: Switch(
            value: profile.isDefault,
            onChanged: (value) => _setDefault(profile, value),
          ),
          onTap: () => _renameProfile(profile),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.copy_outlined),
          title: const Text('复制模板'),
          onTap: () => _duplicateProfile(profile),
        ),
        ListTile(
          leading: const Icon(Icons.rtt),
          title: const Text('调整画布尺寸'),
          subtitle: Text(_formatCanvasSize(profile.canvasSize)),
          onTap: () => _changeCanvasSize(profile),
        ),
        const Divider(),
        ..._buildElementPreview(profile),
      ],
    );
  }

  List<Widget> _buildElementPreview(WatermarkProfile profile) {
    if (profile.elements.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              '暂无元素，点击右下角“编辑画布”开始添加元素',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ];
    }
    return profile.elements
        .sorted((a, b) => a.zIndex.compareTo(b.zIndex))
        .map((element) => ListTile(
              leading: Icon(_iconForType(element.type)),
              title: Text(_titleForElement(element)),
              subtitle: Text(
                  '透明度 ${(element.opacity * 100).round()}% · z-index ${element.zIndex}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeElement(profile, element.id),
              ),
            ))
        .toList();
  }

  Future<void> _openEditor(WatermarkProfile profile) async {
    final edited = await Navigator.of(context).pushNamed(
      WatermarkProfileEditorScreen.routeName,
      arguments: WatermarkProfileEditorArguments(
        profile: profile,
        bootstrapper: widget.bootstrapper,
        fallbackCanvasSize: _cameraCanvas,
      ),
    ) as WatermarkProfile?;
    if (edited == null) {
      return;
    }
    setState(() {
      _profiles = _profiles
          .map((item) => item.id == edited.id ? edited : item)
          .toList();
      _activeProfileId = edited.id;
    });
  }

  void _createTemplate() {
    final profile = WatermarkProfile(
      id: _uuid.v4(),
      name: '模板 ${_profiles.length + 1}',
      elements: const <WatermarkElement>[],
      canvasSize:
          _cameraCanvas ?? const WatermarkCanvasSize(width: 1080, height: 1920),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _profiles = [..._profiles, profile];
      _activeProfileId = profile.id;
    });
  }

  void _duplicateProfile(WatermarkProfile profile) {
    final duplicated = profile.copyWith(
      elements: profile.elements.map((element) => element.copyWith()).toList(),
      name: '${profile.name} 副本',
      updatedAt: DateTime.now(),
    );
    final copy = WatermarkProfile(
      id: _uuid.v4(),
      name: duplicated.name,
      elements: duplicated.elements,
      canvasSize: duplicated.canvasSize,
      updatedAt: duplicated.updatedAt,
    );
    setState(() {
      _profiles = [..._profiles, copy];
      _activeProfileId = copy.id;
    });
  }

  void _deleteProfile(WatermarkProfile profile) {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一个模板')),
      );
      return;
    }
    setState(() {
      _profiles = _profiles.where((item) => item.id != profile.id).toList();
      if (_activeProfileId == profile.id) {
        _activeProfileId = _profiles.first.id;
      }
    });
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

  void _setDefault(WatermarkProfile profile, bool value) {
    setState(() {
      _profiles = _profiles
          .map((item) => item.copyWith(isDefault: item.id == profile.id))
          .toList();
      _activeProfileId = profile.id;
    });
  }

  Future<void> _changeCanvasSize(WatermarkProfile profile) async {
    final size = profile.canvasSize ??
        const WatermarkCanvasSize(width: 1080, height: 1920);
    final widthController =
        TextEditingController(text: size.width.toStringAsFixed(0));
    final heightController =
        TextEditingController(text: size.height.toStringAsFixed(0));
    final result = await showDialog<WatermarkCanvasSize>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('调整画布尺寸'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: widthController,
                decoration: const InputDecoration(labelText: '宽度 (px)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: heightController,
                decoration: const InputDecoration(labelText: '高度 (px)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final width = double.tryParse(widthController.text);
                final height = double.tryParse(heightController.text);
                if (width == null ||
                    height == null ||
                    width <= 0 ||
                    height <= 0) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(
                  context,
                  WatermarkCanvasSize(
                    width: width,
                    height: height,
                    pixelRatio: profile.canvasSize?.pixelRatio ?? 1,
                  ),
                );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (result == null) {
      return;
    }
    setState(() {
      _profiles = _profiles
          .map((item) => item.id == profile.id
              ? item.copyWith(canvasSize: result, updatedAt: DateTime.now())
              : item)
          .toList();
    });
  }

  void _removeElement(WatermarkProfile profile, String elementId) {
    setState(() {
      final updated =
          profile.elements.where((element) => element.id != elementId).toList();
      _profiles = _profiles
          .map((item) => item.id == profile.id
              ? item.copyWith(elements: updated, updatedAt: DateTime.now())
              : item)
          .toList();
    });
  }

  String _formatCanvasSize(WatermarkCanvasSize? size) {
    if (size == null) {
      return '未设置，默认继承相机预览尺寸';
    }
    final ratio = size.width / size.height;
    return '${size.width.toStringAsFixed(0)} × ${size.height.toStringAsFixed(0)}  (比例 ${ratio.toStringAsFixed(2)}:1)';
  }

  IconData _iconForType(WatermarkElementType type) {
    switch (type) {
      case WatermarkElementType.text:
        return Icons.text_fields;
      case WatermarkElementType.time:
        return Icons.access_time;
      case WatermarkElementType.location:
        return Icons.place_outlined;
      case WatermarkElementType.weather:
        return Icons.wb_sunny_outlined;
      case WatermarkElementType.image:
        return Icons.image_outlined;
    }
  }

  String _titleForElement(WatermarkElement element) {
    switch (element.type) {
      case WatermarkElementType.text:
        return element.payload.text ?? '文本元素';
      case WatermarkElementType.time:
        return '时间元素';
      case WatermarkElementType.location:
        return '地点元素';
      case WatermarkElementType.weather:
        return '天气元素';
      case WatermarkElementType.image:
        return '图片元素';
    }
  }
}

class TemplateManagerArguments {
  const TemplateManagerArguments({
    required this.activeProfileId,
    this.cameraCanvas,
  });

  final String activeProfileId;
  final WatermarkCanvasSize? cameraCanvas;
}
