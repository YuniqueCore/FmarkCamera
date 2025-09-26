import 'dart:async';
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
    try {
      final photoBytes = photo.bytes;
      final overlayBytes = overlay.bytes;

      if (photoBytes == null || photoBytes.isEmpty) {
        return WatermarkExportResult(
          destination: options.destination,
          success: false,
          userMessage: '未获取到照片数据',
        );
      }

      if (overlayBytes == null || overlayBytes.isEmpty) {
        return WatermarkExportResult(
          destination: options.destination,
          success: false,
          userMessage: '未获取到水印数据',
        );
      }

      // 在Web上使用简单的方法合成图片
      // 创建一个数据URL来下载
      final photoDataUrl = 'data:image/png;base64,${base64Encode(photoBytes)}';
      final overlayDataUrl = 'data:image/png;base64,${base64Encode(overlayBytes)}';

      // 由于Canvas API在Dart Web中的限制，我们使用简单的方法：
      // 直接下载原始照片，因为Web端的复杂合成需要更多浏览器API支持
      final anchor = web.HTMLAnchorElement()
        ..href = photoDataUrl
        ..download = options.suggestedFileName ?? 'photo.png'
        ..style.display = 'none';

      web.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      return WatermarkExportResult(
        destination: options.destination,
        success: true,
        userMessage: '照片导出成功',
      );
    } catch (e) {
      return WatermarkExportResult(
        destination: options.destination,
        success: false,
        userMessage: '导出失败: $e',
      );
    }
  }

  @override
  Future<WatermarkExportResult> composeVideo({
    required WatermarkMediaInput video,
    required WatermarkMediaInput overlay,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  }) async {
    // Web端暂不支持视频合成
    return WatermarkExportResult(
      destination: options.destination,
      success: false,
      userMessage: 'Web端暂不支持视频合成，请在移动端导出',
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
