import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' as ui;
import 'dart:convert';

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
        _drawText(canvas, element, element.payload.text ?? '',
            alignCenter: true);
        break;
      case WatermarkElementType.time:
        final formatted = _formatTime(context, element);
        _drawText(canvas, element, formatted, alignCenter: false);
        break;
      case WatermarkElementType.location:
        final locationText = _formatLocation(context, element);
        _drawText(canvas, element, locationText, alignCenter: false);
        break;
      case WatermarkElementType.weather:
        final weatherText = _formatWeather(context, element);
        _drawText(canvas, element, weatherText, alignCenter: false);
        break;
      case WatermarkElementType.image:
        await _drawImage(canvas, element);
        break;
    }

    canvas.restore();
  }

  void _drawText(Canvas canvas, WatermarkElement element, String text,
      {required bool alignCenter}) {
    if (text.isEmpty) {
      return;
    }
    final style = element.textStyle?.asTextStyle() ??
        const TextStyle(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          color: (style.color ?? Colors.white)
              .withValues(alpha: element.opacity.clamp(0.0, 1.0)),
        ),
      ),
      textAlign: alignCenter ? TextAlign.center : TextAlign.left,
      textDirection: ui.TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: 400);
    canvas.translate(-painter.width / 2, -painter.height / 2);
    painter.paint(canvas, Offset.zero);
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
      ..color = Colors.white.withValues(alpha: element.opacity.clamp(0.0, 1.0));
    final rect = Rect.fromCenter(
        center: Offset.zero,
        width: image.width.toDouble(),
        height: image.height.toDouble());
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
