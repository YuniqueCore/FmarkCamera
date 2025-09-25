import 'dart:developer' as developer;
import 'dart:io' show File;

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/services/watermark_exporter.dart';

class IoWatermarkExporter implements WatermarkExporter {
  const IoWatermarkExporter();

  @override
  Future<String?> composePhoto({
    required String photoPath,
    required String overlayPath,
  }) async {
    try {
      // 验证输入文件存在
      final photoFile = File(photoPath);
      final overlayFile = File(overlayPath);
      
      if (!await photoFile.exists()) {
        throw Exception('Photo file not found: $photoPath');
      }
      if (!await overlayFile.exists()) {
        throw Exception('Overlay file not found: $overlayPath');
      }
      
      final directory = await getTemporaryDirectory();
      // 确保输出目录存在
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final outputPath = p.join(directory.path, '${const Uuid().v4()}.jpg');
      
      // 构建 FFmpeg 命令，添加更多选项以提高兼容性
      final command = [
        '-y', // 覆盖输出文件
        '-i', photoPath, // 输入照片
        '-i', overlayPath, // 输入水印
        '-filter_complex', 'overlay=0:0', // 水印叠加
        '-q:v', '2', // 高质量输出
        '-pix_fmt', 'yuv420p', // 确保兼容性
        outputPath,
      ].join(' ');
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        // 验证输出文件是否成功创建
        final outputFile = File(outputPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          return outputPath;
        } else {
          throw Exception('Output file was not created or is empty');
        }
      } else {
        // 获取所有日志信息
        final logs = await session.getLogs();
        final logMessages = logs
            .map((log) => log.getMessage())
            .where((message) => message.isNotEmpty)
            .take(5) // 限制日志数量避免过长
            .join('\n');
        throw Exception('FFmpeg photo composition failed: $logMessages');
      }
    } catch (e) {
      // 记录详细错误信息
      developer.log('Photo composition error: $e', name: 'WatermarkExporter');
      return null;
    }
  }

  @override
  Future<String?> composeVideo({
    required String videoPath,
    required String overlayPath,
  }) async {
    try {
      // 验证输入文件存在
      final videoFile = File(videoPath);
      final overlayFile = File(overlayPath);
      
      if (!await videoFile.exists()) {
        throw Exception('Video file not found: $videoPath');
      }
      if (!await overlayFile.exists()) {
        throw Exception('Overlay file not found: $overlayPath');
      }
      
      final directory = await getTemporaryDirectory();
      // 确保输出目录存在
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final outputPath = p.join(directory.path, '${const Uuid().v4()}.mp4');
      
      // 构建 FFmpeg 命令，添加更多选项以提高兼容性和性能
      final command = [
        '-y', // 覆盖输出文件
        '-i', videoPath, // 输入视频
        '-i', overlayPath, // 输入水印
        '-filter_complex', 'overlay=0:0', // 水印叠加
        '-c:a', 'copy', // 音频直接复制，避免重编码
        '-c:v', 'libx264', // 使用 H.264 编码器
        '-preset', 'fast', // 快速编码
        '-crf', '23', // 平衡质量与文件大小
        '-pix_fmt', 'yuv420p', // 确保兼容性
        '-movflags', '+faststart', // 优化网络播放
        outputPath,
      ].join(' ');
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        // 验证输出文件是否成功创建
        final outputFile = File(outputPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          return outputPath;
        } else {
          throw Exception('Output video file was not created or is empty');
        }
      } else {
        // 获取所有日志信息
        final logs = await session.getLogs();
        final logMessages = logs
            .map((log) => log.getMessage())
            .where((message) => message.isNotEmpty)
            .take(5) // 限制日志数量避免过长
            .join('\n');
        throw Exception('FFmpeg video composition failed: $logMessages');
      }
    } catch (e) {
      // 记录详细错误信息
      developer.log('Video composition error: $e', name: 'WatermarkExporter');
      return null;
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
  Future<String?> exportOriginal(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file not found: $sourcePath');
      }
      
      // 检查文件权限
      final stat = await sourceFile.stat();
      if (stat.size == 0) {
        throw Exception('Source file is empty: $sourcePath');
      }
      
      final directory = await getTemporaryDirectory();
      // 确保目录存在
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final originalName = p.basename(sourcePath);
      final extension = p.extension(originalName);
      final destination = p.join(directory.path, '${const Uuid().v4()}$extension');
      
      await sourceFile.copy(destination);
      
      // 验证复制是否成功
      final destinationFile = File(destination);
      if (await destinationFile.exists() && await destinationFile.length() > 0) {
        return destination;
      } else {
        throw Exception('Failed to copy original file');
      }
    } catch (e) {
      developer.log('Export original error: $e', name: 'WatermarkExporter');
      return null;
    }
  }

  @override
  Future<String?> exportWatermarkPng(
    List<int> bytes, {
    String? suggestedName,
  }) async {
    try {
      if (bytes.isEmpty) {
        throw Exception('Empty bytes provided for watermark PNG');
      }
      
      final directory = await getTemporaryDirectory();
      // 确保目录存在
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // 清理文件名，移除非法字符
      String fileName;
      if (suggestedName?.trim().isNotEmpty ?? false) {
        // 移除或替换非法字符
        fileName = suggestedName!.trim()
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
            .replaceAll(RegExp(r'\s+'), '_');
        // 确保有 .png 扩展名
        if (!fileName.toLowerCase().endsWith('.png')) {
          fileName += '.png';
        }
      } else {
        fileName = 'watermark_${const Uuid().v4()}.png';
      }
      
      final path = p.join(directory.path, fileName);
      final file = File(path);
      
      await file.writeAsBytes(bytes, flush: true);
      
      // 验证文件是否成功写入
      if (await file.exists() && await file.length() > 0) {
        return file.path;
      } else {
        throw Exception('Failed to write watermark PNG file');
      }
    } catch (e) {
      developer.log('Export watermark PNG error: $e', name: 'WatermarkExporter');
      return null;
    }
  }
}

WatermarkExporter createWatermarkExporter() => const IoWatermarkExporter();
