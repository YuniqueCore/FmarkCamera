import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/services/watermark_exporter.dart';

class WebWatermarkExporter implements WatermarkExporter {
  const WebWatermarkExporter();

  @override
  Future<WatermarkExportResult> composePhoto({
    required WatermarkMediaInput photo,
    required WatermarkMediaInput overlay,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  }) async {
    return WatermarkExportResult(
      destination: options.destination,
      success: false,
      userMessage: 'Web 平台水印合成仍在建设中，暂需在离线端完成导出',
    );
  }

  @override
  Future<WatermarkExportResult> composeVideo({
    required WatermarkMediaInput video,
    required WatermarkMediaInput overlay,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  }) async {
    return WatermarkExportResult(
      destination: options.destination,
      success: false,
      userMessage: 'Web 平台视频导出暂未实现，请在移动端导出',
    );
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

  @override
  Future<WatermarkExportResult> exportOriginal(
    WatermarkMediaInput source, {
    required WatermarkMediaType mediaType,
    WatermarkExportOptions options = const WatermarkExportOptions(
      destination: WatermarkExportDestination.browserDownload,
    ),
  }) async {
    return WatermarkExportResult(
      destination: options.destination,
      success: false,
      userMessage: 'Web 平台暂不支持直接导出原始文件',
    );
  }

  @override
  Future<WatermarkExportResult> exportWatermarkPng(
    WatermarkMediaInput overlay, {
    String? suggestedName,
    WatermarkExportOptions options = const WatermarkExportOptions(
      destination: WatermarkExportDestination.browserDownload,
    ),
  }) async {
    if (!kIsWeb) {
      return WatermarkExportResult(
        destination: options.destination,
        success: false,
      );
    }
    final bytes = overlay.bytes;
    if (bytes == null || bytes.isEmpty) {
      return WatermarkExportResult(
        destination: options.destination,
        success: false,
        userMessage: '未获取到水印 PNG 数据',
      );
    }
    final fileName = (suggestedName == null || suggestedName.isEmpty)
        ? 'watermark_${const Uuid().v4()}.png'
        : suggestedName;
    final dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
    final anchor = web.HTMLAnchorElement()
      ..href = dataUrl
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return WatermarkExportResult(
      destination: WatermarkExportDestination.browserDownload,
      success: true,
      userMessage: '已触发浏览器下载：$fileName',
    );
  }
}

WatermarkExporter createWatermarkExporter() => const WebWatermarkExporter();
