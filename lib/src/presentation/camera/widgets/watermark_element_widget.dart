import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/models/watermark_transform.dart';

typedef TransformChanged = void Function(WatermarkTransform transform);
typedef OpacityChanged = void Function(double opacity);
typedef ElementDeleted = void Function();
typedef ElementSelected = void Function();

class WatermarkElementWidget extends StatefulWidget {
  const WatermarkElementWidget({
    super.key,
    required this.element,
    required this.contextData,
    required this.canvasSize,
    required this.onTransform,
    required this.selected,
    required this.isEditing,
    this.onOpacityChanged,
    this.onDelete,
    this.onSelected,
  });

  final WatermarkElement element;
  final WatermarkContext contextData;
  final WatermarkCanvasSize canvasSize;
  final TransformChanged onTransform;
  final OpacityChanged? onOpacityChanged;
  final ElementDeleted? onDelete;
  final ElementSelected? onSelected;
  final bool selected;
  final bool isEditing;

  @override
  State<WatermarkElementWidget> createState() => _WatermarkElementWidgetState();
}

class _WatermarkElementWidgetState extends State<WatermarkElementWidget> {
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
  void didUpdateWidget(covariant WatermarkElementWidget oldWidget) {
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
    if (widget.element.isLocked) {
      return;
    }
    _syncFromWidget();
    _lastFocalPoint = details.focalPoint;
    widget.onSelected?.call();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (widget.element.isLocked) {
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
    final content = _buildContent();

    final child = Transform.rotate(
      angle: widget.element.transform.rotation,
      alignment: Alignment.center,
      child: Transform.scale(
        scale: widget.element.transform.scale,
        alignment: Alignment.center,
        child: Opacity(
          opacity: widget.element.opacity,
          child: content,
        ),
      ),
    );

    Widget result = Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onSelected,
        onTapDown: (_) => widget.onSelected?.call(),
        onScaleStart:
            widget.isEditing && !widget.element.isLocked ? _onScaleStart : null,
        onScaleUpdate: widget.isEditing && !widget.element.isLocked
            ? _onScaleUpdate
            : null,
        onScaleEnd:
            widget.isEditing && !widget.element.isLocked ? _onScaleEnd : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: child,
            ),
            if (widget.selected && widget.isEditing)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orangeAccent, width: 1.5),
                  ),
                ),
              ),
            if (widget.selected && widget.isEditing && widget.onDelete != null)
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

    return result;
  }

  Widget _buildContent() {
    switch (widget.element.type) {
      case WatermarkElementType.text:
        return _buildText(widget.element.payload.text ?? '文本',
            align: TextAlign.center);
      case WatermarkElementType.time:
        return _buildText(_formatTime(), align: TextAlign.left);
      case WatermarkElementType.location:
        return _buildText(_formatLocation(), align: TextAlign.left);
      case WatermarkElementType.weather:
        return _buildText(_formatWeather(), align: TextAlign.left);
      case WatermarkElementType.image:
        return _buildImage();
    }
  }

  Widget _buildText(String text, {required TextAlign align}) {
    final style = widget.element.textStyle?.asTextStyle() ??
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
    final asset = widget.element.payload.assetName;
    final filePath = widget.element.payload.imagePath;
    final base64Bytes = widget.element.payload.imageBytesBase64;
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
        DateFormat(widget.element.payload.timeFormat ?? 'yyyy-MM-dd HH:mm:ss');
    return formatter.format(widget.contextData.now);
  }

  String _formatLocation() {
    final location = widget.contextData.location;
    if (location == null) {
      return '定位中...';
    }
    final buffer = StringBuffer();
    if (widget.element.payload.showAddress && location.address != null) {
      buffer.write(location.address);
    } else if (location.city != null) {
      buffer.write(location.city);
    }
    if (widget.element.payload.showCoordinates) {
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(
          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}');
    }
    return buffer.isEmpty ? '定位未获取' : buffer.toString();
  }

  String _formatWeather() {
    final weather = widget.contextData.weather;
    if (weather == null) {
      return '天气获取中...';
    }
    final temperature = '${weather.temperatureCelsius.toStringAsFixed(1)}°C';
    if (!widget.element.payload.showWeatherDescription ||
        weather.description == null) {
      return temperature;
    }
    return '$temperature ${weather.description}';
  }
}
