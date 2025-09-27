import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_element_payload.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/models/watermark_text_style.dart';
import 'package:fmark_camera/src/domain/models/watermark_transform.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/watermark_context_controller.dart';
import 'package:fmark_camera/src/services/watermark_profiles_controller.dart';
import 'package:fmark_camera/src/presentation/widgets/watermark_canvas.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key, required this.arguments});

  static const String routeName = '/profiles/editor';

  final ProfileEditorArguments arguments;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final Uuid _uuid = const Uuid();
  late final WatermarkProfilesController _profilesController;
  late final WatermarkContextController _contextController;

  late WatermarkProfile _profile;
  late WatermarkContext _context;
  String? _selectedElementId;
  bool _showGrid = true;

  @override
  void initState() {
    super.initState();
    final bootstrapper = widget.arguments.bootstrapper;
    _profilesController = bootstrapper.profilesController;
    _contextController = bootstrapper.contextController;
    _context = _contextController.context;
    _contextController.addListener(_handleContextChanged);
    _hydrateProfile();
  }

  void _hydrateProfile() {
    final source = _profilesController.profiles.firstWhere(
      (item) => item.id == widget.arguments.profileId,
      orElse: () => _profilesController.profiles.first,
    );

    // 确保画布尺寸与实际相机配置一致
    final fallbackCanvas = widget.arguments.fallbackCanvasSize ??
        source.canvasSize ??
        const WatermarkCanvasSize(
            width: 1920, height: 1080); // 使用常见的 16:9 比例作为默认

    // 如果提供了 fallback 尺寸但没有设置 canvasSize，则使用 fallback 尺寸
    final canvasSize = source.canvasSize ?? fallbackCanvas;

    _profile = source.copyWith(
      canvasSize: canvasSize,
      elements: source.elements
          .map(
            (element) => WatermarkElement(
              id: element.id,
              type: element.type,
              transform: element.transform,
              opacity: element.opacity,
              textStyle: element.textStyle,
              payload: element.payload,
              zIndex: element.zIndex,
              isLocked: element.isLocked,
            ),
          )
          .toList(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _contextController.removeListener(_handleContextChanged);
    super.dispose();
  }

  void _handleContextChanged() {
    setState(() => _context = _contextController.context);
  }

  WatermarkCanvasSize get _canvasSize =>
      _profile.canvasSize ??
      const WatermarkCanvasSize(width: 1080, height: 1920);

  WatermarkElement? get _selectedElement {
    for (final element in _profile.elements) {
      if (element.id == _selectedElementId) {
        return element;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedElement;
    final selectedElement =
        (selected != null && selected.id.isNotEmpty) ? selected : null;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_profile.name} · 水印编辑'),
        actions: [
          IconButton(
            icon: Icon(_showGrid ? Icons.grid_off : Icons.grid_on),
            tooltip: '切换网格',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF0F1114),
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_showGrid)
                          CustomPaint(
                            painter: _GridPainter(canvasSize: _canvasSize),
                          ),
                        Center(
                          child: AspectRatio(
                            aspectRatio: _canvasSize.width / _canvasSize.height,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B1F24),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: EditableWatermarkCanvas(
                                  elements: _profile.elements,
                                  contextData: _context,
                                  canvasSize: _canvasSize,
                                  selectedElementId: _selectedElementId,
                                  onElementSelected: (id) => setState(() {
                                    _selectedElementId = id;
                                  }),
                                  onElementChanged: _applyElement,
                                  onElementDeleted: _removeElement,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildLayerSidebar(context),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.black.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildAddButton('时间', Icons.access_time, _addTimeElement),
                      _buildAddButton(
                          '地点', Icons.place_outlined, _addLocationElement),
                      _buildAddButton(
                          '天气', Icons.wb_sunny_outlined, _addWeatherElement),
                      _buildAddButton('文本', Icons.text_fields, _addTextElement),
                      _buildAddButton(
                          '图片', Icons.image_outlined, _addImageElement),
                    ],
                  ),
                  if (selectedElement != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '已选元素：${_titleForElement(selectedElement)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _buildOpacitySlider(selectedElement),
                    _buildElementActions(selectedElement),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white10,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildOpacitySlider(WatermarkElement element) {
    return Row(
      children: [
        const Text('透明度', style: TextStyle(color: Colors.white70)),
        Expanded(
          child: Slider(
            value: element.opacity,
            min: 0.1,
            max: 1.0,
            onChanged: (value) => _applyElement(
              element.copyWith(opacity: value),
            ),
          ),
        ),
        Text('${(element.opacity * 100).round()}%',
            style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildElementActions(WatermarkElement element) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text('内容设置'),
                onPressed: () => _openContentSheet(element),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.text_fields),
                label: const Text('文本样式'),
                onPressed: element.type == WatermarkElementType.image
                    ? null
                    : () => _openTextStyleSheet(element),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.transform),
                label: const Text('精细变换'),
                onPressed: () => _openTransformSheet(element),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.layers),
                label: const Text('层级调整'),
                onPressed: () => _openLayerSheet(element),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeElement(element.id),
            ),
          ],
        ),
      ],
    );
  }

  void _addTextElement() {
    _pushElement(
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.text,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.5),
          scale: 1,
          rotation: 0,
        ),
        payload: const WatermarkElementPayload(text: '自定义文本'),
        textStyle: const WatermarkTextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        zIndex: _profile.elements.length,
      ),
    );
  }

  void _addTimeElement() {
    _pushElement(
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.time,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.2),
          scale: 1,
          rotation: 0,
        ),
        textStyle: const WatermarkTextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        payload: const WatermarkElementPayload(
          timeFormat: 'yyyy-MM-dd HH:mm',
        ),
        zIndex: _profile.elements.length,
      ),
    );
  }

  void _addLocationElement() {
    _pushElement(
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.location,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.3),
          scale: 1,
          rotation: 0,
        ),
        textStyle: const WatermarkTextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        payload: const WatermarkElementPayload(
          showAddress: true,
          showCoordinates: false,
        ),
        zIndex: _profile.elements.length,
      ),
    );
  }

  void _addWeatherElement() {
    _pushElement(
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.weather,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.4),
          scale: 1,
          rotation: 0,
        ),
        textStyle: const WatermarkTextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        payload: const WatermarkElementPayload(
          showWeatherDescription: true,
        ),
        zIndex: _profile.elements.length,
      ),
    );
  }

  Future<void> _addImageElement() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) {
      return;
    }
    try {
      final payload = kIsWeb
          ? WatermarkElementPayload(
              imageBytesBase64: base64Encode(await file.readAsBytes()),
            )
          : WatermarkElementPayload(imagePath: file.path);
      _pushElement(
        WatermarkElement(
          id: _uuid.v4(),
          type: WatermarkElementType.image,
          transform: const WatermarkTransform(
            position: Offset(0.5, 0.5),
            scale: 1,
            rotation: 0,
          ),
          payload: payload,
          zIndex: _profile.elements.length,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片导入失败，请重试')),
      );
    }
  }

  void _pushElement(WatermarkElement element) {
    setState(() {
      _profile = _profile.copyWith(
        elements: [..._profile.elements, element],
        updatedAt: DateTime.now(),
      );
      _selectedElementId = element.id;
    });
  }

  void _applyElement(WatermarkElement element) {
    setState(() {
      _profile = _profile.copyWith(
        elements: _profile.elements
            .map((item) => item.id == element.id ? element : item)
            .toList(),
        updatedAt: DateTime.now(),
      );
    });
  }

  void _removeElement(String elementId) {
    final element = _profile.elements.firstWhere((e) => e.id == elementId);
    final elementTitle = _titleForElement(element);

    // 显示确认对话框
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除水印元素'),
        content: Text('确定要删除 "$elementTitle" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _performRemoveElement(elementId);
      }
    });
  }

  void _performRemoveElement(String elementId) {
    setState(() {
      _profile = _profile.copyWith(
        elements: _profile.elements
            .where((element) => element.id != elementId)
            .toList(),
        updatedAt: DateTime.now(),
      );
      if (_selectedElementId == elementId) {
        _selectedElementId = null;
      }
    });

    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('水印元素已删除'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openContentSheet(WatermarkElement element) {
    switch (element.type) {
      case WatermarkElementType.text:
        _openTextSheet(element);
        break;
      case WatermarkElementType.time:
        _openTimeSheet(element);
        break;
      case WatermarkElementType.location:
        _openLocationSheet(element);
        break;
      case WatermarkElementType.weather:
        _openWeatherSheet(element);
        break;
      case WatermarkElementType.image:
        _openImageSheet(element);
        break;
    }
  }

  Future<void> _openTextSheet(WatermarkElement element) async {
    final controller =
        TextEditingController(text: element.payload.text ?? '编辑文本');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文本内容'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '显示文本'),
          maxLines: 3,
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
    if (result == null || result.isEmpty) {
      return;
    }
    _applyElement(
      element.copyWith(
        payload: element.payload.copyWith(text: result),
      ),
    );
  }

  Future<void> _openTimeSheet(WatermarkElement element) async {
    final presets = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy/MM/dd HH:mm',
      'MM 月 dd 日 HH:mm',
      'HH:mm:ss',
    ];
    final controller = TextEditingController(
      text: element.payload.timeFormat ?? presets.first,
    );
    String preview = _formatTimePreview(controller.text);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('时间格式',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: '格式化 pattern',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => setModalState(
                          () => preview = _formatTimePreview(value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: presets.contains(controller.text)
                            ? controller.text
                            : null,
                        decoration: const InputDecoration(
                          labelText: '快速选择',
                          border: OutlineInputBorder(),
                        ),
                        items: presets
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          controller.text = value;
                          setModalState(
                            () => preview = _formatTimePreview(value),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text('预览：$preview',
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text.trim()),
                          child: const Text('确定'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) {
      return;
    }
    _applyElement(
      element.copyWith(
        payload: element.payload.copyWith(timeFormat: result),
      ),
    );
  }

  Future<void> _openLocationSheet(WatermarkElement element) async {
    var showAddress = element.payload.showAddress;
    var showCoordinates = element.payload.showCoordinates;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('地点显示',
                        style: Theme.of(context).textTheme.titleMedium),
                    SwitchListTile(
                      title: const Text('显示地址/地名'),
                      value: showAddress,
                      onChanged: (value) =>
                          setModalState(() => showAddress = value),
                    ),
                    SwitchListTile(
                      title: const Text('显示经纬度'),
                      value: showCoordinates,
                      onChanged: (value) =>
                          setModalState(() => showCoordinates = value),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    _applyElement(
      element.copyWith(
        payload: element.payload.copyWith(
          showAddress: showAddress,
          showCoordinates: showCoordinates,
        ),
      ),
    );
  }

  Future<void> _openWeatherSheet(WatermarkElement element) async {
    var showDescription = element.payload.showWeatherDescription;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('天气显示',
                        style: Theme.of(context).textTheme.titleMedium),
                    SwitchListTile(
                      title: const Text('显示天气描述'),
                      value: showDescription,
                      onChanged: (value) =>
                          setModalState(() => showDescription = value),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    _applyElement(
      element.copyWith(
        payload:
            element.payload.copyWith(showWeatherDescription: showDescription),
      ),
    );
  }

  Future<void> _openImageSheet(WatermarkElement element) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('重新选择图片'),
                onTap: () async {
                  Navigator.pop(context);
                  await _replaceImage(element);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('移除图片'),
                onTap: () {
                  Navigator.pop(context);
                  _applyElement(
                    element.copyWith(
                      payload: element.payload.copyWith(
                        imagePath: '',
                        imageBytesBase64: '',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _replaceImage(WatermarkElement element) async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) {
      return;
    }
    try {
      final payload = kIsWeb
          ? element.payload.copyWith(
              imageBytesBase64: base64Encode(await file.readAsBytes()),
              imagePath: '',
            )
          : element.payload.copyWith(
              imagePath: file.path,
              imageBytesBase64: '',
            );
      _applyElement(element.copyWith(payload: payload));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片导入失败，请重试')),
      );
    }
  }

  Future<void> _openTextStyleSheet(WatermarkElement element) async {
    final initial = element.textStyle ?? const WatermarkTextStyle();
    var fontSize = initial.fontSize;
    var isBold = initial.fontWeight.index >= FontWeight.w600.index;
    var color = initial.color;
    const palette = <Color>[
      Colors.white,
      Colors.black,
      Colors.orangeAccent,
      Colors.lightBlueAccent,
      Colors.redAccent,
      Colors.greenAccent,
    ];
    final fontController =
        TextEditingController(text: fontSize.toStringAsFixed(0));
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              void syncFont(double value) {
                final clamped = value.clamp(8, 120);
                setModalState(() {
                  fontSize = clamped.toDouble();
                  fontController.text = fontSize.toStringAsFixed(0);
                });
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('文本样式',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('字号',
                            style: TextStyle(color: Colors.white70)),
                        Expanded(
                          child: Slider(
                            value: fontSize.clamp(8, 120),
                            min: 8,
                            max: 120,
                            onChanged: syncFont,
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: TextField(
                            controller: fontController,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: false,
                              decimal: false,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final parsed = double.tryParse(value);
                              if (parsed != null) {
                                syncFont(parsed);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('加粗'),
                      value: isBold,
                      onChanged: (value) => setModalState(() => isBold = value),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: palette
                            .map(
                              (candidate) => GestureDetector(
                                onTap: () =>
                                    setModalState(() => color = candidate),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: candidate,
                                  child: color == candidate
                                      ? Icon(
                                          Icons.check,
                                          size: 14,
                                          color:
                                              candidate.computeLuminance() > 0.5
                                                  ? Colors.black
                                                  : Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _applyElement(
                            element.copyWith(
                              textStyle: WatermarkTextStyle(
                                fontSize: fontSize,
                                fontWeight:
                                    isBold ? FontWeight.w700 : FontWeight.w500,
                                color: color,
                                background: initial.background,
                                shadow: initial.shadow,
                                letterSpacing: initial.letterSpacing,
                              ),
                            ),
                          );
                        },
                        child: const Text('应用'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    fontController.dispose();
  }

  Future<void> _openTransformSheet(WatermarkElement element) async {
    final position = element.transform.position;
    final scale = element.transform.scale;
    final rotation = element.transform.rotation;
    final positionX =
        TextEditingController(text: position.dx.toStringAsFixed(3));
    final positionY =
        TextEditingController(text: position.dy.toStringAsFixed(3));
    final scaleController =
        TextEditingController(text: scale.toStringAsFixed(2));
    final rotationController = TextEditingController(
        text: (rotation * 180 / math.pi).toStringAsFixed(1));
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('精细调整', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: positionX,
                          decoration:
                              const InputDecoration(labelText: 'X (0-1)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: positionY,
                          decoration:
                              const InputDecoration(labelText: 'Y (0-1)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: scaleController,
                          decoration: const InputDecoration(labelText: '缩放'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: rotationController,
                          decoration:
                              const InputDecoration(labelText: '旋转 (°)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('应用'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    final xText = positionX.text;
    final yText = positionY.text;
    final scaleText = scaleController.text;
    final rotationText = rotationController.text;
    positionX.dispose();
    positionY.dispose();
    scaleController.dispose();
    rotationController.dispose();
    if (confirmed != true) {
      return;
    }
    final dx = double.tryParse(xText)?.clamp(0.0, 1.0) ?? position.dx;
    final dy = double.tryParse(yText)?.clamp(0.0, 1.0) ?? position.dy;
    final newScale =
        double.tryParse(scaleText)?.clamp(0.3, 3.0) ?? scale;
    final degrees = double.tryParse(rotationText) ?? 0;
    final radians = (degrees * math.pi) / 180;
    _applyElement(
      element.copyWith(
        transform: element.transform.copyWith(
          position: Offset(dx, dy),
          scale: newScale,
          rotation: radians,
        ),
      ),
    );
  }

  Future<void> _openLayerSheet(WatermarkElement element) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('层级调整', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _bumpLayer(element, 1),
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('上移'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _bumpLayer(element, -1),
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('下移'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _setLayer(element, _profile.elements.length - 1),
                      icon: const Icon(Icons.vertical_align_top),
                      label: const Text('置顶'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _setLayer(element, 0),
                      icon: const Icon(Icons.vertical_align_bottom),
                      label: const Text('置底'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayerSidebar(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    if (availableWidth < 720) {
      return const SizedBox(width: 0);
    }
    final elements = [..._profile.elements]
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF141820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.layers, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  '元素层级 (${elements.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: elements.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '暂无元素',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Text(
                          '点击下方按钮添加',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: elements.length,
                    buildDefaultDragHandles: false,
                    onReorder: _onLayerReorder,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blueAccent,
                              width: 2,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    itemBuilder: (context, index) {
                      final element = elements[index];
                      final selected = element.id == _selectedElementId;
                      final title = _titleForElement(element);
                      final icon = _iconForElementType(element.type);
                      return Container(
                        key: ValueKey(element.id),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.orangeAccent.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                selected ? Colors.orangeAccent : Colors.white12,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: selected
                                ? Colors.orangeAccent.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.1),
                            child: Icon(icon, color: Colors.white70, size: 16),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '层级 ${elements.length - index}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 可见性切换
                              IconButton(
                                iconSize: 16,
                                icon: Icon(
                                  element.opacity > 0.5
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                tooltip:
                                    element.opacity > 0.5 ? '隐藏元素' : '显示元素',
                                color: element.opacity > 0.5
                                    ? Colors.greenAccent
                                    : Colors.white38,
                                onPressed: () =>
                                    _toggleElementVisibility(element),
                              ),
                              IconButton(
                                iconSize: 18,
                                icon: Icon(
                                  element.isLocked
                                      ? Icons.lock
                                      : Icons.lock_open,
                                ),
                                tooltip: element.isLocked ? '解锁元素' : '锁定元素',
                                color: element.isLocked
                                    ? Colors.amberAccent
                                    : Colors.white54,
                                onPressed: () => _toggleElementLock(element),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(
                                  Icons.drag_indicator,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _selectedElementId = element.id;
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _onLayerReorder(int oldIndex, int newIndex) {
    final ordered = [..._profile.elements]
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    final ascending = ordered.reversed.toList();
    final updated = <WatermarkElement>[];
    for (var i = 0; i < ascending.length; i++) {
      updated.add(ascending[i].copyWith(zIndex: i));
    }
    setState(() {
      _profile = _profile.copyWith(
        elements: updated,
        updatedAt: DateTime.now(),
      );
    });
  }

  IconData _iconForElementType(WatermarkElementType type) {
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

  void _toggleElementLock(WatermarkElement element) {
    _applyElement(
      element.copyWith(isLocked: !element.isLocked),
    );
  }

  // 新增：切换元素可见性
  void _toggleElementVisibility(WatermarkElement element) {
    final newOpacity = element.opacity > 0.5 ? 0.3 : 1.0;
    _applyElement(
      element.copyWith(opacity: newOpacity),
    );

    // 显示操作反馈
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newOpacity > 0.5 ? '元素已显示' : '元素已隐藏'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _bumpLayer(WatermarkElement element, int delta) {
    final current =
        _profile.elements.indexWhere((item) => item.id == element.id);
    if (current == -1) {
      return;
    }
    final target = (current + delta).clamp(0, _profile.elements.length - 1);
    _setLayer(element, target);
  }

  void _setLayer(WatermarkElement element, int targetIndex) {
    final current =
        _profile.elements.indexWhere((item) => item.id == element.id);
    if (current == -1) {
      return;
    }
    final updated = [..._profile.elements];
    final item = updated.removeAt(current);
    updated.insert(targetIndex.clamp(0, updated.length), item);
    for (var i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(zIndex: i);
    }
    setState(() {
      _profile = _profile.copyWith(
        elements: updated,
        updatedAt: DateTime.now(),
      );
    });
  }

  String _titleForElement(WatermarkElement element) {
    switch (element.type) {
      case WatermarkElementType.text:
        return element.payload.text ?? '文本';
      case WatermarkElementType.time:
        return '时间';
      case WatermarkElementType.location:
        return '地点';
      case WatermarkElementType.weather:
        return '天气';
      case WatermarkElementType.image:
        return '图片';
    }
  }

  String _formatTimePreview(String pattern) {
    try {
      return DateFormat(pattern).format(_context.now);
    } catch (_) {
      return '格式不合法';
    }
  }

  Future<void> _save() async {
    await _profilesController.updateProfile(
      _profile.copyWith(
        elements: _profile.elements
            .map(
              (element) => WatermarkElement(
                id: element.id,
                type: element.type,
                transform: element.transform,
                opacity: element.opacity,
                textStyle: element.textStyle,
                payload: element.payload,
                zIndex: element.zIndex,
                isLocked: element.isLocked,
              ),
            )
            .toList(),
        updatedAt: DateTime.now(),
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(_profile);
  }
}

class ProfileEditorArguments {
  const ProfileEditorArguments({
    required this.profileId,
    required this.bootstrapper,
    this.fallbackCanvasSize,
  });

  final String profileId;
  final Bootstrapper bootstrapper;
  final WatermarkCanvasSize? fallbackCanvasSize;
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.canvasSize});

  final WatermarkCanvasSize canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke;
    const step = 0.1;
    for (double x = 0; x <= 1; x += step) {
      final dx = x * size.width;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    }
    for (double y = 0; y <= 1; y += step) {
      final dy = y * size.height;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
