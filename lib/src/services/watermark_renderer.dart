import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';

class WatermarkRenderer {
  Future<Uint8List> renderToBytes({
    required WatermarkProfile profile,
    required WatermarkContext context,
    required Size canvasSize,
    double scaleFactor = 1,
  }) async {
    final image = await renderToImage(
      profile: profile,
      context: context,
      canvasSize: canvasSize,
      scaleFactor: scaleFactor,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return Uint8List(0);
    }
    return byteData.buffer.asUint8List();
  }

  Future<ui.Image> renderToImage({
    required WatermarkProfile profile,
    required WatermarkContext context,
    required Size canvasSize,
    double scaleFactor = 1,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & canvasSize);

    final ordered = [...profile.elements]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    for (final element in ordered) {
      await _drawElement(canvas, canvasSize, element, context, scaleFactor);
    }

    return recorder.endRecording().toImage(
          canvasSize.width.toInt(),
          canvasSize.height.toInt(),
        );
  }

  Future<void> _drawElement(
    Canvas canvas,
    Size canvasSize,
    WatermarkElement element,
    WatermarkContext context,
    double scaleFactor,
  ) async {
    final position = Offset(
      element.transform.position.dx * canvasSize.width,
      element.transform.position.dy * canvasSize.height,
    );
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(element.transform.rotation);
    canvas.scale(element.transform.scale * scaleFactor);

    switch (element.type) {
      case WatermarkElementType.text:
        _drawText(
          canvas,
          canvasSize,
          element,
          element.payload.text ?? '',
          alignCenter: true,
        );
        break;
      case WatermarkElementType.time:
        final formatted = _formatTime(context, element);
        _drawText(
          canvas,
          canvasSize,
          element,
          formatted,
          alignCenter: false,
        );
        break;
      case WatermarkElementType.location:
        final locationText = _formatLocation(context, element);
        _drawText(
          canvas,
          canvasSize,
          element,
          locationText,
          alignCenter: false,
        );
        break;
      case WatermarkElementType.weather:
        final weatherText = _formatWeather(context, element);
        _drawText(
          canvas,
          canvasSize,
          element,
          weatherText,
          alignCenter: false,
        );
        break;
      case WatermarkElementType.image:
        await _drawImage(canvas, element);
        break;
    }

    canvas.restore();
  }

  void _drawText(
    Canvas canvas,
    Size canvasSize,
    WatermarkElement element,
    String text, {
    required bool alignCenter,
  }) {
    if (text.isEmpty) {
      return;
    }
    final textStyle = _resolveTextStyle(element);
    final baseColor = textStyle.color ?? Colors.white;
    final baseAlpha = baseColor.a;
    final colorWithOpacity = baseColor.withValues(
      alpha: (baseAlpha * element.opacity).clamp(0.0, 1.0),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(color: colorWithOpacity),
      ),
      textAlign: alignCenter ? TextAlign.center : TextAlign.left,
      textDirection: ui.TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: canvasSize.width);

    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    final totalWidth = painter.width + padding.horizontal;
    final totalHeight = painter.height + padding.vertical;
    final paintOrigin = Offset(
      -totalWidth / 2 + padding.left,
      -totalHeight / 2 + padding.top,
    );

    final backgroundColor = element.textStyle?.background;
    if (backgroundColor != null) {
      final backgroundAlpha = backgroundColor.a;
      final adjustedBackground = backgroundColor.withValues(
        alpha: (backgroundAlpha * element.opacity).clamp(0.0, 1.0),
      );
      final rect = Rect.fromLTWH(
        -totalWidth / 2,
        -totalHeight / 2,
        totalWidth,
        totalHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = adjustedBackground,
      );
    }

    painter.paint(canvas, paintOrigin);
  }

  TextStyle _resolveTextStyle(WatermarkElement element) {
    final base = element.textStyle?.asTextStyle() ??
        const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );
    final hasShadow = base.shadows != null && base.shadows!.isNotEmpty;
    if (hasShadow) {
      return base;
    }
    return base.copyWith(
      shadows: const [
        Shadow(
          color: Colors.black54,
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  Future<void> _drawImage(Canvas canvas, WatermarkElement element) async {
    final path = element.payload.imagePath;
    final asset = element.payload.assetName;
    final base64Bytes = element.payload.imageBytesBase64;
    Uint8List? bytes;
    if (path != null && path.isNotEmpty) {
      bytes = await File(path).readAsBytes();
    } else if (asset != null && asset.isNotEmpty) {
      final data = await rootBundle.load(asset);
      bytes = data.buffer.asUint8List();
    } else if (base64Bytes != null && base64Bytes.isNotEmpty) {
      try {
        bytes = base64Decode(base64Bytes);
      } catch (_) {}
    }
    if (bytes == null) {
      return;
    }
    final image = await decodeImageFromList(bytes);
    final paint = Paint()
      ..color = Colors.white.withValues(
        alpha: element.opacity.clamp(0.0, 1.0),
      );
    const baseSize = 96.0;
    final widthScale = baseSize / image.width;
    final heightScale = baseSize / image.height;
    final scale = math.min(widthScale, heightScale);
    final targetWidth = image.width * scale;
    final targetHeight = image.height * scale;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: targetWidth,
      height: targetHeight,
    );
    canvas.translate(-rect.width / 2, -rect.height / 2);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      paint,
    );
  }

  Future<ui.Image> decodeImageFromList(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  String _formatTime(WatermarkContext context, WatermarkElement element) {
    final format = element.payload.timeFormat ?? 'yyyy-MM-dd HH:mm';
    return DateFormat(format).format(context.now);
  }

  String _formatLocation(WatermarkContext context, WatermarkElement element) {
    final location = context.location;
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
          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}');
    }
    return buffer.isEmpty ? '定位未获取' : buffer.toString();
  }

  String _formatWeather(WatermarkContext context, WatermarkElement element) {
    final weather = context.weather;
    if (weather == null) {
      return '天气获取中...';
    }
    final temp = '${weather.temperatureCelsius.toStringAsFixed(1)}°C';
    if (!element.payload.showWeatherDescription ||
        weather.description == null) {
      return temp;
    }
    return '$temp ${weather.description}';
  }
}
