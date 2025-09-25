import 'dart:convert';
import 'dart:io' show File;

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
  });

  final WatermarkElement element;
  final WatermarkContext contextData;
  final WatermarkCanvasSize canvasSize;

  @override
  Widget build(BuildContext context) {
    final position = element.transform.position;
    final size = canvasSize.toSize();
    final left = position.dx * size.width;
    final top = position.dy * size.height;
    return Positioned(
      left: left,
      top: top,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: element.transform.rotation,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: element.transform.scale,
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
    required this.onTransform,
    required this.selected,
    this.onDelete,
    this.onSelected,
    this.isLocked = false,
  });

  final WatermarkElement element;
  final WatermarkContext contextData;
  final WatermarkCanvasSize canvasSize;
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
    final canvasSize = widget.canvasSize.toSize();
    if (_lastFocalPoint != null &&
        canvasSize.width > 0 &&
        canvasSize.height > 0) {
      final delta = details.focalPoint - _lastFocalPoint!;
      _lastFocalPoint = details.focalPoint;
      final normalized = Offset(
        delta.dx / canvasSize.width,
        delta.dy / canvasSize.height,
      );
      _currentPosition = Offset(
        (_currentPosition.dx + normalized.dx).clamp(0.0, 1.0),
        (_currentPosition.dy + normalized.dy).clamp(0.0, 1.0),
      );
    }
    final scale = (_initialScale * details.scale).clamp(0.3, 3.0);
    final rotation = _initialRotation + details.rotation;
    widget.onTransform(
      widget.element.transform.copyWith(
        position: _currentPosition,
        scale: scale,
        rotation: rotation,
      ),
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.element.transform.position;
    final size = widget.canvasSize.toSize();
    final left = position.dx * size.width;
    final top = position.dy * size.height;
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onSelected,
        onTapDown: (_) => widget.onSelected?.call(),
        onScaleStart: widget.isLocked ? null : _onScaleStart,
        onScaleUpdate: widget.isLocked ? null : _onScaleUpdate,
        onScaleEnd: widget.isLocked ? null : _onScaleEnd,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: Transform.rotate(
                angle: widget.element.transform.rotation,
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: widget.element.transform.scale,
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: widget.element.opacity,
                    child: _WatermarkElementContent(
                      element: widget.element,
                      contextData: widget.contextData,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.selected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orangeAccent, width: 1.5),
                  ),
                ),
              ),
            if (widget.selected && widget.onDelete != null)
              Positioned(
                top: -32,
                right: -32,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(6),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                ),
              ),
          ],
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
    final style = element.textStyle?.asTextStyle() ??
        const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: align,
        style: style,
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
