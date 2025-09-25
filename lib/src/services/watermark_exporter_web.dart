import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/services/watermark_exporter.dart';

class WebWatermarkExporter implements WatermarkExporter {
  const WebWatermarkExporter();

  @override
  Future<String?> composePhoto({
    required String photoPath,
    required String overlayPath,
  }) async {
    // FFmpeg is unavailable on Web; return null to signal unsupported feature.
    return null;
  }

  @override
  Future<String?> composeVideo({
    required String videoPath,
    required String overlayPath,
  }) async {
    // Video composition is not supported on Web.
    return null;
  }

  @override
  Future<String?> saveOverlayBytes(List<int> bytes) async {
    if (!kIsWeb) {
      return null;
    }
    final dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
    final fileName = 'overlay_${const Uuid().v4()}.png';
    final anchor = web.HTMLAnchorElement()
      ..href = dataUrl
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return null;
  }
}

WatermarkExporter createWatermarkExporter() => const WebWatermarkExporter();

