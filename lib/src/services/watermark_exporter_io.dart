import 'dart:developer' as developer;
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:gal/gal.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/services/watermark_exporter.dart';

class IoWatermarkExporter implements WatermarkExporter {
  const IoWatermarkExporter();

  @override
  Future<WatermarkExportResult> composePhoto({
    required WatermarkMediaInput photo,
    required WatermarkMediaInput overlay,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  }) async {
    try {
      final photoPath = await _materializeInput(
        photo,
        fallbackExtension: '.jpg',
      );
      final overlayPath = await _materializeInput(
        overlay,
        fallbackExtension: '.png',
      );
      if (photoPath == null || !await File(photoPath).exists()) {
        return _failureResult(
          destination: options.destination,
          message: '未找到原始照片文件',
        );
      }
      if (overlayPath == null || !await File(overlayPath).exists()) {
        return _failureResult(
          destination: options.destination,
          message: '未找到水印叠加文件',
        );
      }
      final tempPath = await _runFfmpegCompose(
        inputs: ['-i', photoPath, '-i', overlayPath],
        filters: 'overlay=0:0',
        extension: '.jpg',
        extraArgs: const ['-q:v', '2', '-pix_fmt', 'yuv420p'],
      );
      if (tempPath == null) {
        return _failureResult(
          destination: options.destination,
          message: 'FFmpeg 未生成有效的水印照片',
        );
      }
      return await _handleDestination(
        sourcePath: tempPath,
        options: options,
        mediaType: WatermarkMediaType.photo,
        defaultFileName:
            options.suggestedFileName ?? 'watermark_${const Uuid().v4()}.jpg',
      );
    } catch (e, stack) {
      developer.log(
        'Photo composition error: $e',
        name: 'WatermarkExporter',
        stackTrace: stack,
      );
      return _failureResult(
        destination: options.destination,
        message: e.toString(),
      );
    }
  }

  @override
  Future<WatermarkExportResult> composeVideo({
    required WatermarkMediaInput video,
    required WatermarkMediaInput overlay,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  }) async {
    try {
      final videoPath = await _materializeInput(
        video,
        fallbackExtension: '.mp4',
      );
      final overlayPath = await _materializeInput(
        overlay,
        fallbackExtension: '.png',
      );
      if (videoPath == null || !await File(videoPath).exists()) {
        return _failureResult(
          destination: options.destination,
          message: '未找到原始视频文件',
        );
      }
      if (overlayPath == null || !await File(overlayPath).exists()) {
        return _failureResult(
          destination: options.destination,
          message: '未找到水印叠加文件',
        );
      }
      final tempPath = await _runFfmpegCompose(
        inputs: ['-i', videoPath, '-i', overlayPath],
        filters: 'overlay=0:0',
        extension: '.mp4',
        extraArgs: const [
          '-c:a',
          'copy',
          '-c:v',
          'libx264',
          '-preset',
          'fast',
          '-crf',
          '23',
          '-pix_fmt',
          'yuv420p',
          '-movflags',
          '+faststart',
        ],
      );
      if (tempPath == null) {
        return _failureResult(
          destination: options.destination,
          message: 'FFmpeg 未生成有效的水印视频',
        );
      }
      return await _handleDestination(
        sourcePath: tempPath,
        options: options,
        mediaType: WatermarkMediaType.video,
        defaultFileName:
            options.suggestedFileName ?? 'watermark_${const Uuid().v4()}.mp4',
      );
    } catch (e, stack) {
      developer.log(
        'Video composition error: $e',
        name: 'WatermarkExporter',
        stackTrace: stack,
      );
      return _failureResult(
        destination: options.destination,
        message: e.toString(),
      );
    }
  }

  @override
  Future<String?> saveOverlayBytes(List<int> bytes) async {
    try {
      if (bytes.isEmpty) {
        throw Exception('Empty bytes provided for overlay');
      }

      final directory = await getTemporaryDirectory();
      // 确保目录存在
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final path = p.join(directory.path, '${const Uuid().v4()}.png');
      final file = File(path);

      await file.writeAsBytes(bytes, flush: true);

      // 验证文件是否成功写入
      if (await file.exists() && await file.length() > 0) {
        return file.path;
      } else {
        throw Exception('Failed to write overlay file');
      }
    } catch (e) {
      developer.log('Save overlay bytes error: $e', name: 'WatermarkExporter');
      return null;
    }
  }

  @override
  Future<WatermarkExportResult> exportOriginal(
    WatermarkMediaInput source, {
    required WatermarkMediaType mediaType,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  }) async {
    try {
      final sourcePath = await _materializeInput(source);
      if (sourcePath == null) {
        return _failureResult(
          destination: options.destination,
          message: '未找到原始文件',
        );
      }
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return _failureResult(
          destination: options.destination,
          message: '未找到原始文件',
        );
      }
      final stat = await sourceFile.stat();
      if (stat.size == 0) {
        return _failureResult(
          destination: options.destination,
          message: '原始文件为空',
        );
      }
      final directory = await getTemporaryDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final originalName = p.basename(sourcePath);
      final destination = p.join(
        directory.path,
        '${const Uuid().v4()}${p.extension(originalName)}',
      );
      await sourceFile.copy(destination);
      return await _handleDestination(
        sourcePath: destination,
        options: options,
        mediaType: mediaType,
        defaultFileName: options.suggestedFileName ?? originalName,
      );
    } catch (e, stack) {
      developer.log(
        'Export original error: $e',
        name: 'WatermarkExporter',
        stackTrace: stack,
      );
      return _failureResult(
        destination: options.destination,
        message: e.toString(),
      );
    }
  }

  @override
  Future<WatermarkExportResult> exportWatermarkPng(
    WatermarkMediaInput overlay, {
    String? suggestedName,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  }) async {
    try {
      final bytes = await _resolveBytes(overlay);
      if (bytes == null || bytes.isEmpty) {
        return _failureResult(
          destination: options.destination,
          message: '水印 PNG 数据为空',
        );
      }
      final directory = await getTemporaryDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final sanitizedName = _sanitizeFileName(
        suggestedName ?? 'watermark_${const Uuid().v4()}.png',
        fallbackExtension: '.png',
      );
      final path = p.join(directory.path, sanitizedName);
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('生成水印 PNG 失败');
      }
      return await _handleDestination(
        sourcePath: path,
        options: options,
        mediaType: WatermarkMediaType.photo,
        defaultFileName: sanitizedName,
      );
    } catch (e, stack) {
      developer.log(
        'Export watermark PNG error: $e',
        name: 'WatermarkExporter',
        stackTrace: stack,
      );
      return _failureResult(
        destination: options.destination,
        message: e.toString(),
      );
    }
  }

  Future<String?> _materializeInput(
    WatermarkMediaInput input, {
    String? fallbackExtension,
  }) async {
    if (input.hasPath) {
      return input.path;
    }
    if (input.hasBytes) {
      final directory = await getTemporaryDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final path = p.join(
        directory.path,
        '${const Uuid().v4()}${fallbackExtension ?? ''}',
      );
      final file = File(path);
      await file.writeAsBytes(input.bytes!, flush: true);
      return file.path;
    }
    return null;
  }

  Future<Uint8List?> _resolveBytes(WatermarkMediaInput input) async {
    if (input.bytes != null && input.bytes!.isNotEmpty) {
      return input.bytes;
    }
    if (input.path != null && input.path!.isNotEmpty) {
      try {
        return await File(input.path!).readAsBytes();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<String?> _runFfmpegCompose({
    required List<String> inputs,
    required String filters,
    required String extension,
    List<String> extraArgs = const <String>[],
  }) async {
    final directory = await getTemporaryDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final outputPath = p.join(directory.path, '${const Uuid().v4()}$extension');
    final command = [
      '-y',
      ...inputs,
      '-filter_complex',
      filters,
      ...extraArgs,
      outputPath,
    ].join(' ');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      final outputFile = File(outputPath);
      if (await outputFile.exists() && await outputFile.length() > 0) {
        return outputPath;
      }
      return null;
    }
    final logs = await session.getLogs();
    final logMessages = logs
        .map((log) => log.getMessage())
        .where((message) => message.isNotEmpty)
        .take(5)
        .join('\n');
    throw Exception('FFmpeg 执行失败：$logMessages');
  }

  Future<WatermarkExportResult> _handleDestination({
    required String sourcePath,
    required WatermarkExportOptions options,
    required WatermarkMediaType mediaType,
    required String defaultFileName,
  }) async {
    switch (options.destination) {
      case WatermarkExportDestination.temporary:
        return WatermarkExportResult(
          destination: WatermarkExportDestination.temporary,
          outputPath: sourcePath,
        );
      case WatermarkExportDestination.gallery:
        final success = await _saveToGallery(sourcePath, mediaType);
        return WatermarkExportResult(
          destination: WatermarkExportDestination.gallery,
          outputPath: sourcePath,
          success: success,
          userMessage: success ? '已保存到系统相册' : '保存到系统相册失败，请检查权限',
        );
      case WatermarkExportDestination.filePicker:
        final savedPath = await _saveWithFileDialog(
          sourcePath,
          options.suggestedFileName ?? defaultFileName,
        );
        return WatermarkExportResult(
          destination: WatermarkExportDestination.filePicker,
          outputPath: savedPath ?? sourcePath,
          success: savedPath != null,
          userMessage: savedPath == null ? '未选择导出位置或保存失败' : null,
        );
      case WatermarkExportDestination.browserDownload:
        final fallbackPath = await _saveWithFileDialog(
          sourcePath,
          options.suggestedFileName ?? defaultFileName,
        );
        final success = fallbackPath != null;
        return WatermarkExportResult(
          destination: success
              ? WatermarkExportDestination.filePicker
              : WatermarkExportDestination.browserDownload,
          outputPath: fallbackPath ?? sourcePath,
          success: success,
          userMessage: success ? null : '当前平台不支持浏览器下载，已生成临时文件：$sourcePath',
        );
    }
  }

  Future<bool> _saveToGallery(
    String sourcePath,
    WatermarkMediaType mediaType,
  ) async {
    try {
      await Gal.requestAccess();
    } catch (e) {
      developer.log('Gal request access failed: $e', name: 'WatermarkExporter');
    }
    try {
      if (mediaType == WatermarkMediaType.photo) {
        await Gal.putImage(sourcePath);
      } else {
        await Gal.putVideo(sourcePath);
      }
      return true;
    } catch (e, stack) {
      developer.log(
        'Gal save error: $e',
        name: 'WatermarkExporter',
        stackTrace: stack,
      );
    }
    try {
      final saved = mediaType == WatermarkMediaType.photo
          ? await GallerySaver.saveImage(sourcePath)
          : await GallerySaver.saveVideo(sourcePath);
      return saved ?? false;
    } catch (e, stack) {
      developer.log(
        'GallerySaver fallback error: $e',
        name: 'WatermarkExporter',
        stackTrace: stack,
      );
    }
    return false;
  }

  Future<String?> _saveWithFileDialog(
    String sourcePath,
    String fileName,
  ) async {
    try {
      final params = SaveFileDialogParams(
        sourceFilePath: sourcePath,
        fileName: _sanitizeFileName(fileName),
      );
      return await FlutterFileDialog.saveFile(params: params);
    } catch (e, stack) {
      developer.log(
        'Save file dialog error: $e',
        name: 'WatermarkExporter',
        stackTrace: stack,
      );
      return null;
    }
  }

  WatermarkExportResult _failureResult({
    required WatermarkExportDestination destination,
    String? message,
  }) {
    return WatermarkExportResult(
      destination: destination,
      success: false,
      userMessage: message,
    );
  }

  String _sanitizeFileName(
    String fileName, {
    String fallbackExtension = '',
  }) {
    final trimmed = fileName.trim().isEmpty
        ? 'watermark_${const Uuid().v4()}$fallbackExtension'
        : fileName.trim();
    final sanitized = trimmed
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (fallbackExtension.isNotEmpty &&
        !sanitized.toLowerCase().endsWith(fallbackExtension)) {
      return '$sanitized$fallbackExtension';
    }
    return sanitized;
  }
}

WatermarkExporter createWatermarkExporter() => const IoWatermarkExporter();
