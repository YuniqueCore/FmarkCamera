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
  late double _currentScale;
  late double _startScale;
  late double _initialRotation;
  Offset? _lastFocalPoint;
  int _activePointers = 0;

  Offset? _rotationCenterGlobal;
  Offset? _rotationStartVector;
  double _rotationBaseAngle = 0;

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
    _currentScale = transform.scale;
    _startScale = transform.scale;
    _initialRotation = transform.rotation;
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (widget.isLocked) {
      return;
    }
    _syncFromWidget();
    _activePointers = details.pointerCount;
    _lastFocalPoint = details.focalPoint;
    widget.onSelected?.call();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (widget.isLocked) {
      return;
    }
    final previousPointers = _activePointers;
    _activePointers = details.pointerCount;
    if (previousPointers < 2 && details.pointerCount >= 2) {
      _startScale = _currentScale;
    }
    if (previousPointers >= 2 && details.pointerCount < 2) {
      _lastFocalPoint = details.focalPoint;
    }

    final renderSize = widget.renderSize;

    if (details.pointerCount <= 1 &&
        _lastFocalPoint != null &&
        renderSize.width > 0 &&
        renderSize.height > 0) {
      final delta = details.focalPoint - _lastFocalPoint!;
      final normalized = Offset(
        delta.dx / renderSize.width,
        delta.dy / renderSize.height,
      );
      _currentPosition = Offset(
        (_currentPosition.dx + normalized.dx).clamp(0.0, 1.0),
        (_currentPosition.dy + normalized.dy).clamp(0.0, 1.0),
      );
      _lastFocalPoint = details.focalPoint;
    } else if (details.pointerCount > 1) {
      _lastFocalPoint = null;
    }

    if (details.pointerCount >= 2) {
      final nextScale = (_startScale * details.scale).clamp(0.2, 5.0);
      _currentScale = nextScale;
    }

    widget.onTransform(
      widget.element.transform.copyWith(
        position: _currentPosition,
        scale: _currentScale,
        rotation: _initialRotation,
      ),
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
    _startScale = _currentScale;
    _initialRotation = widget.element.transform.rotation;
    _activePointers = 0;
  }

  void _onRotationDragStart(DragStartDetails details) {
    if (widget.isLocked) {
      return;
    }
    widget.onSelected?.call();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final centerLocal = Offset(
      widget.element.transform.position.dx * widget.renderSize.width,
      widget.element.transform.position.dy * widget.renderSize.height,
    );
    _rotationCenterGlobal = box.localToGlobal(centerLocal);
    _rotationStartVector =
        details.globalPosition - (_rotationCenterGlobal ?? details.globalPosition);
    _rotationBaseAngle = widget.element.transform.rotation;
  }

  void _onRotationDragUpdate(DragUpdateDetails details) {
    if (widget.isLocked) {
      return;
    }
    if (_rotationCenterGlobal == null || _rotationStartVector == null) {
      return;
    }
    final currentVector = details.globalPosition - _rotationCenterGlobal!;
    if (currentVector.distanceSquared == 0) {
      return;
    }
    final startDirection = _rotationStartVector!.direction;
    final currentDirection = currentVector.direction;
    var rotation = _rotationBaseAngle + (currentDirection - startDirection);
    rotation = _wrapAngle(rotation);
    widget.onTransform(
      widget.element.transform.copyWith(rotation: rotation),
    );
    _initialRotation = rotation;
  }

  void _onRotationDragEnd(DragEndDetails details) {
    _rotationCenterGlobal = null;
    _rotationStartVector = null;
    _rotationBaseAngle = _initialRotation;
  }

  double _wrapAngle(double angle) {
    const fullTurn = 2 * math.pi;
    var normalized = angle;
    while (normalized <= -math.pi) {
      normalized += fullTurn;
    }
    while (normalized > math.pi) {
      normalized -= fullTurn;
    }
    return normalized;
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
                          onPanEnd: _onRotationDragEnd,
                          isLocked: widget.isLocked,
                        ),
                      ),
                    ),
                  if (widget.selected && widget.onDelete != null)
                    Positioned(
                      top: -16,
                      right: -16,
                      child: _DeleteHandle(
                        onPressed: widget.isLocked ? null : widget.onDelete,
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
    required this.onPanEnd,
    required this.isLocked,
  });

  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final enabled = !isLocked;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: enabled ? onPanStart : null,
      onPanUpdate: enabled ? onPanUpdate : null,
      onPanEnd: enabled ? onPanEnd : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? Colors.blueAccent : Colors.white24,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: const Icon(
          Icons.rotate_90_degrees_ccw,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

class _DeleteHandle extends StatelessWidget {
  const _DeleteHandle({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}

