import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/models/watermark_transform.dart';

/// 只读水印元素，用于相机实时叠加与图库预览。
class WatermarkElementView extends StatelessWidget {
  const WatermarkElementView({
    super.key,
    required this.element,
    required this.contextData,
    required this.canvasSize,
    required this.renderSize,
  });

  final WatermarkElement element;
  final WatermarkContext contextData;
  final WatermarkCanvasSize canvasSize;
  final Size renderSize;

  double get _displayScale {
    final baseWidth = canvasSize.width;
    final baseHeight = canvasSize.height;
    if (baseWidth <= 0 || baseHeight <= 0) {
      return 1;
    }
    final scaleX = renderSize.width / baseWidth;
    final scaleY = renderSize.height / baseHeight;
    return (scaleX + scaleY) * 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final position = element.transform.position;
    final effectiveScale = element.transform.scale * _displayScale;
    final alignment = Alignment(
      (position.dx.clamp(0.0, 1.0) * 2) - 1,
      (position.dy.clamp(0.0, 1.0) * 2) - 1,
    );
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: element.transform.rotation,
        alignment: Alignment.center,
        child: Transform.scale(
          scale: effectiveScale,
          alignment: Alignment.center,
          child: Opacity(
            opacity: element.opacity,
            child: _WatermarkElementContent(
              element: element,
              contextData: contextData,
            ),
          ),
        ),
      ),
    );
  }
}

/// 可编辑水印元素，支持拖拽/缩放/旋转。
class EditableWatermarkElement extends StatefulWidget {
  const EditableWatermarkElement({
    super.key,
    required this.element,
    required this.contextData,
    required this.canvasSize,
    required this.renderSize,
    required this.onTransform,
    required this.selected,
    this.onDelete,
    this.onSelected,
    this.isLocked = false,
  });

  final WatermarkElement element;
  final WatermarkContext contextData;
  final WatermarkCanvasSize canvasSize;
  final Size renderSize;
  final ValueChanged<WatermarkTransform> onTransform;
  final bool selected;
  final VoidCallback? onDelete;
  final VoidCallback? onSelected;
  final bool isLocked;

  @override
  State<EditableWatermarkElement> createState() =>
      _EditableWatermarkElementState();
}

class _EditableWatermarkElementState extends State<EditableWatermarkElement> {
  late Offset _currentPosition;
  late double _initialScale;
  late double _initialRotation;
  Offset? _lastFocalPoint;
  double _rotationDuringDrag = 0;

  static const double _nudgeStep = 0.01;
  static const double _scaleStep = 0.05;
  static const double _rotationStep = math.pi / 90; // 2° increments

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant EditableWatermarkElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.element.id != widget.element.id ||
        oldWidget.element.transform != widget.element.transform) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    final transform = widget.element.transform;
    _currentPosition = transform.position;
    _initialScale = transform.scale;
    _initialRotation = transform.rotation;
    _rotationDuringDrag = transform.rotation;
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (widget.isLocked) {
      return;
    }
    _syncFromWidget();
    _lastFocalPoint = details.focalPoint;
    widget.onSelected?.call();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (widget.isLocked) {
      return;
    }
    final renderSize = widget.renderSize;
    if (_lastFocalPoint != null &&
        renderSize.width > 0 &&
        renderSize.height > 0) {
      final delta = details.focalPoint - _lastFocalPoint!;
      _lastFocalPoint = details.focalPoint;
      final normalized = Offset(
        delta.dx / renderSize.width,
        delta.dy / renderSize.height,
      );
      _currentPosition = Offset(
        (_currentPosition.dx + normalized.dx).clamp(0.0, 1.0),
        (_currentPosition.dy + normalized.dy).clamp(0.0, 1.0),
      );
    }
    final scale = (_initialScale * details.scale).clamp(0.3, 3.0);
    widget.onTransform(
      widget.element.transform.copyWith(
        position: _currentPosition,
        scale: scale,
        rotation: _initialRotation,
      ),
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
  }

  void _onRotationDragStart(DragStartDetails details) {
    if (widget.isLocked) {
      return;
    }
    widget.onSelected?.call();
    _rotationDuringDrag = widget.element.transform.rotation;
  }

  void _onRotationDragUpdate(DragUpdateDetails details) {
    if (widget.isLocked) {
      return;
    }
    final nextRotation = (_rotationDuringDrag + details.delta.dx * 0.01)
        .clamp(-math.pi, math.pi);
    _rotationDuringDrag = nextRotation;
    widget.onTransform(
      widget.element.transform.copyWith(rotation: nextRotation),
    );
  }

  void _nudgePosition(Offset delta) {
    if (widget.isLocked) {
      return;
    }
    final normalized = Offset(
      (widget.element.transform.position.dx + delta.dx).clamp(0.0, 1.0),
      (widget.element.transform.position.dy + delta.dy).clamp(0.0, 1.0),
    );
    widget.onTransform(
      widget.element.transform.copyWith(position: normalized),
    );
  }

  void _adjustScale(double delta) {
    if (widget.isLocked) {
      return;
    }
    final scale = (widget.element.transform.scale + delta).clamp(0.3, 3.0);
    widget.onTransform(
      widget.element.transform.copyWith(scale: scale),
    );
  }

  void _adjustRotation(double delta) {
    if (widget.isLocked) {
      return;
    }
    final rotation = widget.element.transform.rotation + delta;
    widget.onTransform(
      widget.element.transform.copyWith(rotation: rotation),
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.element.transform.position;
    final renderSize = widget.renderSize;
    final baseWidth = widget.canvasSize.width;
    final baseHeight = widget.canvasSize.height;
    final scaleX = baseWidth <= 0 ? 1.0 : renderSize.width / baseWidth;
    final scaleY = baseHeight <= 0 ? 1.0 : renderSize.height / baseHeight;
    final displayScale = (scaleX + scaleY) * 0.5;
    final effectiveScale = widget.element.transform.scale * displayScale;
    final alignment = Alignment(
      (position.dx.clamp(0.0, 1.0) * 2) - 1,
      (position.dy.clamp(0.0, 1.0) * 2) - 1,
    );

    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onSelected,
        onTapDown: (_) => widget.onSelected?.call(),
        onScaleStart: widget.isLocked ? null : _onScaleStart,
        onScaleUpdate: widget.isLocked ? null : _onScaleUpdate,
        onScaleEnd: widget.isLocked ? null : _onScaleEnd,
        child: Transform.rotate(
          angle: widget.element.transform.rotation,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: effectiveScale,
            alignment: Alignment.center,
            child: Opacity(
              opacity: widget.element.opacity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _WatermarkElementContent(
                    element: widget.element,
                    contextData: widget.contextData,
                  ),
                  if (widget.selected)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.orangeAccent, width: 1.5),
                        ),
                      ),
                    ),
                  if (widget.selected)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Stack(
                          children: [
                            _SelectionHandle(alignment: Alignment.topLeft),
                            _SelectionHandle(alignment: Alignment.topRight),
                            _SelectionHandle(alignment: Alignment.bottomLeft),
                            _SelectionHandle(alignment: Alignment.bottomRight),
                          ],
                        ),
                      ),
                    ),
                  if (widget.selected)
                    Positioned(
                      top: -48,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _RotationHandle(
                          onPanStart: _onRotationDragStart,
                          onPanUpdate: _onRotationDragUpdate,
                          isLocked: widget.isLocked,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WatermarkElementContent extends StatelessWidget {
  const _WatermarkElementContent({
    required this.element,
    required this.contextData,
  });

  final WatermarkElement element;
  final WatermarkContext contextData;

  @override
  Widget build(BuildContext context) {
    switch (element.type) {
      case WatermarkElementType.text:
        return _buildText(element.payload.text ?? '文本', TextAlign.center);
      case WatermarkElementType.time:
        return _buildText(_formatTime(), TextAlign.left);
      case WatermarkElementType.location:
        return _buildText(_formatLocation(), TextAlign.left);
      case WatermarkElementType.weather:
        return _buildText(_formatWeather(), TextAlign.left);
      case WatermarkElementType.image:
        return _buildImage();
    }
  }

  Widget _buildText(String text, TextAlign align) {
    final baseStyle = element.textStyle?.asTextStyle() ??
        const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );
    final effectiveStyle =
        (baseStyle.shadows == null || baseStyle.shadows!.isEmpty)
            ? baseStyle.copyWith(
                shadows: const [
                  Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ],
              )
            : baseStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: effectiveStyle,
      ),
    );
  }

  Widget _buildImage() {
    final asset = element.payload.assetName;
    final filePath = element.payload.imagePath;
    final base64Bytes = element.payload.imageBytesBase64;
    Widget? image;
    if (asset != null && asset.isNotEmpty) {
      image = Image.asset(asset, width: 96, height: 96, fit: BoxFit.contain);
    } else if (kIsWeb && base64Bytes != null && base64Bytes.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Bytes);
        image = Image.memory(bytes, width: 96, height: 96, fit: BoxFit.contain);
      } catch (_) {}
    } else if (filePath != null && filePath.isNotEmpty) {
      if (kIsWeb) {
        image = Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.hide_image_outlined, color: Colors.white),
        );
      } else {
        image = Image.file(
          File(filePath),
          width: 96,
          height: 96,
          fit: BoxFit.contain,
        );
      }
    }
    image ??= Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image_outlined, color: Colors.white),
    );
    return image;
  }

  String _formatTime() {
    final formatter =
        DateFormat(element.payload.timeFormat ?? 'yyyy-MM-dd HH:mm:ss');
    return formatter.format(contextData.now);
  }

  String _formatLocation() {
    final location = contextData.location;
    if (location == null) {
      return '定位中...';
    }
    final buffer = StringBuffer();
    if (element.payload.showAddress && location.address != null) {
      buffer.write(location.address);
    } else if (location.city != null) {
      buffer.write(location.city);
    }
    if (element.payload.showCoordinates) {
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(
        '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
      );
    }
    return buffer.isEmpty ? '定位未获取' : buffer.toString();
  }

  String _formatWeather() {
    final weather = contextData.weather;
    if (weather == null) {
      return '天气获取中...';
    }
    final temperature = '${weather.temperatureCelsius.toStringAsFixed(1)}°C';
    if (!element.payload.showWeatherDescription ||
        weather.description == null) {
      return temperature;
    }
    return '$temperature ${weather.description}';
  }
}

class _SelectionHandle extends StatelessWidget {
  const _SelectionHandle({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 2),
          ],
        ),
      ),
    );
  }
}

class _RotationHandle extends StatelessWidget {
  const _RotationHandle({
    required this.onPanStart,
    required this.onPanUpdate,
    required this.isLocked,
  });

  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final enabled = !isLocked;
    return GestureDetector(
      onPanStart: enabled ? onPanStart : null,
      onPanUpdate: enabled ? onPanUpdate : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? Colors.blueAccent : Colors.white24,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Icon(Icons.rotate_right, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _ElementToolbar extends StatelessWidget {
  const _ElementToolbar({
    required this.isLocked,
    required this.onDelete,
    required this.onNudge,
    required this.onScale,
    required this.onRotate,
    required this.nudgeStep,
    required this.scaleStep,
    required this.rotationStep,
  });

  final bool isLocked;
  final VoidCallback? onDelete;
  final void Function(Offset delta) onNudge;
  final void Function(double delta) onScale;
  final void Function(double delta) onRotate;
  final double nudgeStep;
  final double scaleStep;
  final double rotationStep;

  @override
  Widget build(BuildContext context) {
    final enabled = !isLocked;
    final actions = <Widget>[
      if (onDelete != null)
        _ToolbarButton(
          icon: Icons.delete_outline,
          enabled: enabled,
          tooltip: '删除元素',
          onPressed: onDelete,
        ),
      _ToolbarButton(
        icon: Icons.arrow_upward,
        enabled: enabled,
        tooltip: '上移',
        onPressed: () => onNudge(Offset(0, -nudgeStep)),
      ),
      _ToolbarButton(
        icon: Icons.arrow_downward,
        enabled: enabled,
        tooltip: '下移',
        onPressed: () => onNudge(Offset(0, nudgeStep)),
      ),
      _ToolbarButton(
        icon: Icons.arrow_back,
        enabled: enabled,
        tooltip: '左移',
        onPressed: () => onNudge(Offset(-nudgeStep, 0)),
      ),
      _ToolbarButton(
        icon: Icons.arrow_forward,
        enabled: enabled,
        tooltip: '右移',
        onPressed: () => onNudge(Offset(nudgeStep, 0)),
      ),
      const SizedBox(width: 8),
      _ToolbarButton(
        icon: Icons.zoom_in,
        enabled: enabled,
        tooltip: '放大',
        onPressed: () => onScale(scaleStep),
      ),
      _ToolbarButton(
        icon: Icons.zoom_out,
        enabled: enabled,
        tooltip: '缩小',
        onPressed: () => onScale(-scaleStep),
      ),
      const SizedBox(width: 8),
      _ToolbarButton(
        icon: Icons.rotate_left,
        enabled: enabled,
        tooltip: '向左旋转',
        onPressed: () => onRotate(-rotationStep),
      ),
      _ToolbarButton(
        icon: Icons.rotate_right,
        enabled: enabled,
        tooltip: '向右旋转',
        onPressed: () => onRotate(rotationStep),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: actions,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      iconSize: 18,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: enabled ? Colors.white : Colors.white24),
    );
    return Tooltip(
      message: tooltip,
      child: button,
    );
  }
}
