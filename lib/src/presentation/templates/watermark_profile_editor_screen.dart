import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_element_payload.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/models/watermark_transform.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';
import 'package:fmark_camera/src/services/watermark_context_controller.dart';
import 'package:fmark_camera/src/presentation/camera/widgets/watermark_canvas.dart';

class WatermarkProfileEditorScreen extends StatefulWidget {
  const WatermarkProfileEditorScreen({super.key, required this.arguments});

  static const String routeName = '/templates/editor';

  final WatermarkProfileEditorArguments arguments;

  @override
  State<WatermarkProfileEditorScreen> createState() =>
      _WatermarkProfileEditorScreenState();
}

class _WatermarkProfileEditorScreenState
    extends State<WatermarkProfileEditorScreen> {
  final Uuid _uuid = const Uuid();
  late final WatermarkContextController _contextController;
  late WatermarkProfile _profile;
  String? _selectedElementId;
  bool _showGrid = true;

  late final WatermarkContext _currentContext;

  WatermarkContext get _context => _currentContext;

  @override
  void initState() {
    super.initState();
    final bootstrapper = widget.arguments.bootstrapper;
    _contextController = bootstrapper.contextController;
    _profile = widget.arguments.profile;
    _currentContext = _contextController.context;
    _contextController.addListener(_handleContextChanged);
  }

  void _handleContextChanged() {
    setState(() {
      _currentContext = _contextController.context;
    });
  }

  @override
  void dispose() {
    _contextController.removeListener(_handleContextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize = _profile.canvasSize ??
        const WatermarkCanvasSize(width: 1080, height: 1920);
    return AnimatedBuilder(
      animation: _contextController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${_profile.name} - 画布编辑'),
            actions: [
              IconButton(
                icon: Icon(_showGrid ? Icons.grid_off : Icons.grid_on),
                tooltip: '切换网格',
                onPressed: () => setState(() => _showGrid = !_showGrid),
              ),
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: '保存',
                onPressed: () {
                  Navigator.of(context).pop(_profile);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black87),
                    if (_showGrid)
                      CustomPaint(
                        painter: _GridPainter(canvasSize: canvasSize),
                      ),
                    Center(
                      child: AspectRatio(
                        aspectRatio: canvasSize.width / canvasSize.height,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: WatermarkCanvas(
                            elements: _profile.elements,
                            contextData: _context,
                            selectedElementId: _selectedElementId,
                            isEditing: true,
                            canvasSize: canvasSize,
                            onElementSelected: _onElementSelected,
                            onElementChanged: _onElementChanged,
                            onElementDeleted: _removeElement,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildToolbar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    const watermarkElement = WatermarkElement(
      id: '',
      type: WatermarkElementType.text,
      transform: WatermarkTransform(
        position: Offset(0.5, 0.5),
        scale: 1,
        rotation: 0,
      ),
    );

    final selected = _profile.elements.firstWhere(
      (element) => element.id == _selectedElementId,
      orElse: () => watermarkElement,
    );
    final hasSelection = selected.id.isNotEmpty;
    return SafeArea(
      top: false,
      child: ToolbarContainer(
        hasSelection: hasSelection,
        addButtons: [
          _buildAddButton('时间', Icons.access_time, _addTimeElement),
          _buildAddButton('地点', Icons.place_outlined, _addLocationElement),
          _buildAddButton('天气', Icons.wb_sunny_outlined, _addWeatherElement),
          _buildAddButton('文本', Icons.text_fields, _addTextElement),
          _buildAddButton('图片', Icons.image_outlined, _addImageElement),
        ],
        onReset: hasSelection ? () => _resetElement(selected) : null,
        onOpenLayer: hasSelection ? () => _openLayerDialog(selected) : null,
        inspector: hasSelection ? _buildElementInspector(selected) : null,
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

  Widget _buildElementInspector(WatermarkElement element) {
    final sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: Colors.orangeAccent,
      thumbColor: Colors.orangeAccent,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '已选元素：${_titleForElement(element)}',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('透明度', style: TextStyle(color: Colors.white70)),
            Expanded(
              child: SliderTheme(
                data: sliderTheme,
                child: Slider(
                  value: element.opacity,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (value) {
                    _updateElement(element.copyWith(opacity: value));
                  },
                ),
              ),
            ),
            Text('${(element.opacity * 100).round()}%',
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.text_fields),
                label: const Text('文本样式'),
                onPressed: element.type == WatermarkElementType.image
                    ? null
                    : () => _openTextStyleEditor(element),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('变换详情'),
                onPressed: () => _openTransformSheet(element),
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

  void _onElementSelected(String? id) {
    setState(() => _selectedElementId = id);
  }

  void _onElementChanged(WatermarkElement element) {
    _updateElement(element.copyWith(transform: element.transform));
  }

  void _updateElement(WatermarkElement updated) {
    setState(() {
      _profile = _profile.copyWith(
        elements: _profile.elements
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
        updatedAt: DateTime.now(),
      );
    });
  }

  void _removeElement(String elementId) {
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
  }

  void _resetElement(WatermarkElement element) {
    _updateElement(
      element.copyWith(
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.5),
          scale: 1,
          rotation: 0,
        ),
      ),
    );
  }

  void _openLayerDialog(WatermarkElement element) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('调整层级', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _changeLayer(element, 1),
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('上移一层'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _changeLayer(element, -1),
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('下移一层'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _setLayer(element, _profile.elements.length),
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

  void _changeLayer(WatermarkElement element, int delta) {
    final currentIndex =
        _profile.elements.indexWhere((item) => item.id == element.id);
    if (currentIndex == -1) {
      return;
    }
    final newIndex =
        (currentIndex + delta).clamp(0, _profile.elements.length - 1);
    final updated = [..._profile.elements];
    final item = updated.removeAt(currentIndex);
    updated.insert(newIndex, item);
    _reassignZIndex(updated);
  }

  void _setLayer(WatermarkElement element, int targetIndex) {
    final currentIndex =
        _profile.elements.indexWhere((item) => item.id == element.id);
    if (currentIndex == -1) {
      return;
    }
    final updated = [..._profile.elements];
    final item = updated.removeAt(currentIndex);
    final clamped = targetIndex.clamp(0, updated.length);
    updated.insert(clamped, item);
    _reassignZIndex(updated);
  }

  void _reassignZIndex(List<WatermarkElement> elements) {
    final reassigned = <WatermarkElement>[];
    for (var i = 0; i < elements.length; i++) {
      reassigned.add(elements[i].copyWith(zIndex: i));
    }
    setState(() {
      _profile = _profile.copyWith(
        elements: reassigned,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _addTextElement() {
    _addElement(
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.text,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.5),
          scale: 1,
          rotation: 0,
        ),
        payload: const WatermarkElementPayload(text: '编辑文本'),
      ),
    );
  }

  void _addTimeElement() {
    _addElement(
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.time,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.3),
          scale: 1,
          rotation: 0,
        ),
      ),
    );
  }

  void _addLocationElement() {
    _addElement(
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.location,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.4),
          scale: 1,
          rotation: 0,
        ),
      ),
    );
  }

  void _addWeatherElement() {
    _addElement(
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.weather,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.2),
          scale: 1,
          rotation: 0,
        ),
      ),
    );
  }

  void _addImageElement() {
    _addElement(
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.image,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.6),
          scale: 1,
          rotation: 0,
        ),
        payload: const WatermarkElementPayload(
          imagePath: '',
        ),
      ),
    );
  }

  void _addElement(WatermarkElement element) {
    setState(() {
      _profile = _profile.copyWith(
        elements: [
          ..._profile.elements,
          element.copyWith(zIndex: _profile.elements.length)
        ],
        updatedAt: DateTime.now(),
      );
      _selectedElementId = element.id;
    });
  }

  void _openTextStyleEditor(WatermarkElement element) {
    // Placeholder for future detailed text style editor.
  }

  void _openTransformSheet(WatermarkElement element) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
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
          text: (rotation * 180 / ui.lerpDouble(1, 1, 0)!).toStringAsFixed(1),
        );
        return Padding(
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
                      decoration: const InputDecoration(labelText: 'X (0-1)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: positionY,
                      decoration: const InputDecoration(labelText: 'Y (0-1)'),
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
                      decoration: const InputDecoration(labelText: '旋转 (°)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final x =
                          double.tryParse(positionX.text)?.clamp(0.0, 1.0) ??
                              position.dx;
                      final y =
                          double.tryParse(positionY.text)?.clamp(0.0, 1.0) ??
                              position.dy;
                      final newScale = double.tryParse(scaleController.text)
                              ?.clamp(0.3, 3.0) ??
                          scale;
                      final degrees =
                          double.tryParse(rotationController.text) ?? 0;
                      final radians = (degrees * math.pi) / 180;
                      _updateElement(
                        element.copyWith(
                          transform: element.transform.copyWith(
                            position: Offset(x, y),
                            scale: newScale,
                            rotation: radians,
                          ),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('确定'),
                  )
                ],
              ),
            ],
          ),
        );
      },
    );
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
}

class WatermarkProfileEditorArguments {
  const WatermarkProfileEditorArguments({
    required this.profile,
    required this.bootstrapper,
  });

  final WatermarkProfile profile;
  final Bootstrapper bootstrapper;
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.canvasSize});

  final WatermarkCanvasSize canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
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

class ToolbarContainer extends StatelessWidget {
  const ToolbarContainer({
    super.key,
    required this.hasSelection,
    required this.addButtons,
    required this.onReset,
    required this.onOpenLayer,
    required this.inspector,
  });

  final bool hasSelection;
  final List<Widget> addButtons;
  final VoidCallback? onReset;
  final VoidCallback? onOpenLayer;
  final Widget? inspector;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: addButtons,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_outlined),
                tooltip: '重置选中元素',
                onPressed: onReset,
              ),
              IconButton(
                icon: const Icon(Icons.layers),
                tooltip: '层级调整',
                onPressed: onOpenLayer,
              ),
            ],
          ),
          if (inspector != null) ...[
            const SizedBox(height: 12),
            inspector!,
          ],
        ],
      ),
    );
  }
}
